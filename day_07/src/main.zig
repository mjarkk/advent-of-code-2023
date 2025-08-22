const std = @import("std");
const Tuple = std.meta.Tuple;

pub fn main() !void {
    const start = std.time.nanoTimestamp();

    const puzzle = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, "puzzle.txt", 1024 * 16);

    const result = try calculate(puzzle);

    std.debug.print("p1: {d}, p2: {d}\n", .{ result[0], result[1] });

    const end = std.time.nanoTimestamp();
    const duration_ns = end - start;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;
    std.debug.print("Function took: {} ns ({d:.2} ms)\n", .{ duration_ns, duration_ms });
}

const Answers = Tuple(&.{ usize, usize });

const Card = enum(u4) { _2, _3, _4, _5, _6, _7, _8, _9, T, Joker, Q, K, A };

const Strength = enum(u4) { FiveOfAKind, FourOfAKind, FullHouse, ThreeOfAKind, TwoPair, OnePair, HighCard };

const Hand = struct {
    cards: [5]Card,
    score: u15,
    not_empty: u1,

    cards_score: usize,
    cards_score_with_joker: usize,
    strength: Strength,
    strength_with_jokers: Strength,

    pub fn new(cards: [5]Card, score: u15) Hand {
        var cards_score: usize = 0;
        var cards_score_with_joker: usize = 0;

        var five_of_a_kind = false;
        var four_of_a_kind = false;
        var three_of_a_kind = false;
        var two_of_a_kind = false;

        var card_count: [13]u4 = std.mem.zeroes([13]u4);
        for (cards, 0..) |card, idx| {
            const card_num: usize = @intFromEnum(card);

            const score_exp: u6 = @truncate((cards.len - idx - 1) * 10);
            cards_score += card_num << score_exp;

            var joker_card_num = card_num + 1;
            if (card == Card.Joker) {
                joker_card_num = 0;
            }
            cards_score_with_joker += joker_card_num << score_exp;

            const new_num_cards = card_count[card_num] + 1;
            card_count[card_num] = new_num_cards;

            switch (new_num_cards) {
                5 => five_of_a_kind = true,
                4 => four_of_a_kind = true,
                3 => three_of_a_kind = true,
                2 => two_of_a_kind = true,
                else => {},
            }
        }

        var strength: Strength = .HighCard;
        if (five_of_a_kind) {
            strength = .FiveOfAKind;
        } else if (four_of_a_kind) {
            strength = .FourOfAKind;
        } else if (three_of_a_kind) {
            // Firstly we need to check if this is a full house
            for (card_count) |count| {
                if (count == 2) {
                    strength = .FullHouse;
                    break;
                } else if (count == 1) {
                    // We know from this point on that there is no way to have a Full house
                    break;
                }
            }
            if (strength == .HighCard) {
                strength = .ThreeOfAKind;
            }
        } else if (two_of_a_kind) {
            // Firstly check if there are multiple 2 pairs
            var two_pair_count: u2 = 0;
            for (card_count) |count| {
                if (count == 2) {
                    two_pair_count += 1;
                }
            }
            if (two_pair_count == 2) {
                strength = .TwoPair;
            } else {
                strength = .OnePair;
            }
        }

        var strength_with_jokers: Strength = strength;
        const total_jokers = card_count[@intFromEnum(Card.Joker)];
        if (total_jokers > 0 and total_jokers < 5) {
            four_of_a_kind = false;
            three_of_a_kind = false;
            var total_two_of_a_kind: u2 = 0;
            for (card_count, 0..) |count, card| {
                if (card == @intFromEnum(Card.Joker)) continue;

                switch (count) {
                    4 => four_of_a_kind = true,
                    3 => three_of_a_kind = true,
                    2 => total_two_of_a_kind += 1,
                    else => {},
                }
            }

            if (four_of_a_kind) {
                // There is one joker as the other cards are the same so we can create a five of a kind
                strength_with_jokers = .FiveOfAKind;
            } else if (three_of_a_kind) {
                if (total_jokers == 2) {
                    strength_with_jokers = .FiveOfAKind;
                } else {
                    strength_with_jokers = .FourOfAKind;
                }
            } else if (total_two_of_a_kind > 0) {
                switch (total_jokers) {
                    3 => strength_with_jokers = .FiveOfAKind,
                    2 => strength_with_jokers = .FourOfAKind,
                    1 => {
                        if (total_two_of_a_kind == 2) {
                            strength_with_jokers = .FullHouse;
                        } else {
                            strength_with_jokers = .ThreeOfAKind;
                        }
                    },
                    else => unreachable,
                }
            } else {
                switch (total_jokers) {
                    4 => strength_with_jokers = .FiveOfAKind,
                    3 => strength_with_jokers = .FourOfAKind,
                    2 => strength_with_jokers = .ThreeOfAKind,
                    1 => strength_with_jokers = .OnePair,
                    else => unreachable,
                }
            }
        }

        return Hand{
            .cards = cards,
            .score = score,
            .not_empty = 1,
            .cards_score = cards_score,
            .cards_score_with_joker = cards_score_with_joker,
            .strength = strength,
            .strength_with_jokers = strength_with_jokers,
        };
    }
};

fn cmpHandsPart1(_: void, a: Hand, b: Hand) bool {
    const a_strength = @intFromEnum(a.strength);
    const b_strength = @intFromEnum(b.strength);

    if (a_strength == b_strength) return a.cards_score < b.cards_score;

    return a_strength > b_strength;
}

fn cmpHandsPart2(_: void, a: Hand, b: Hand) bool {
    const a_strength = @intFromEnum(a.strength_with_jokers);
    const b_strength = @intFromEnum(b.strength_with_jokers);

    if (a_strength == b_strength) return a.cards_score_with_joker < b.cards_score_with_joker;

    return a_strength > b_strength;
}

fn calculate(puzzle: []const u8) !Answers {
    var hands = try parse_puzzle(puzzle);

    std.mem.sort(Hand, &hands, {}, cmpHandsPart1);
    var total_score_part_1: usize = 0;
    for (hands, 1..) |hand, multiplier| {
        if (hand.not_empty == 0) continue;
        total_score_part_1 += multiplier * @as(usize, hand.score);
    }

    std.mem.sort(Hand, &hands, {}, cmpHandsPart2);
    var total_score_part_2: usize = 0;
    for (hands, 1..) |hand, multiplier| {
        if (hand.not_empty == 0) continue;
        total_score_part_2 += multiplier * @as(usize, hand.score);
    }

    return .{ total_score_part_1, total_score_part_2 };
}

fn parse_puzzle(puzzle: []const u8) ![1000]Hand {
    var hands_offset: u16 = 0;
    var hands: [1000]Hand = std.mem.zeroes([1000]Hand);

    var is_hand = true;
    var hand_offset: u3 = 0;
    var score_bytes_offset: u3 = 0;
    var hand: [5]Card = undefined;
    var score_bytes: [4]u8 = undefined;
    for (puzzle) |char| {
        if (char == ' ') {
            is_hand = false;
        } else if (char == '\n') {
            is_hand = true;
            const score = try std.fmt.parseUnsigned(u15, score_bytes[0..score_bytes_offset], 10);

            hand_offset = 0;
            score_bytes_offset = 0;

            hands[hands_offset] = Hand.new(hand, score);
            hands_offset += 1;
        } else if (is_hand) {
            switch (char) {
                'A' => hand[hand_offset] = Card.A,
                'K' => hand[hand_offset] = Card.K,
                'Q' => hand[hand_offset] = Card.Q,
                'J' => hand[hand_offset] = Card.Joker,
                'T' => hand[hand_offset] = Card.T,
                '9' => hand[hand_offset] = Card._9,
                '8' => hand[hand_offset] = Card._8,
                '7' => hand[hand_offset] = Card._7,
                '6' => hand[hand_offset] = Card._6,
                '5' => hand[hand_offset] = Card._5,
                '4' => hand[hand_offset] = Card._4,
                '3' => hand[hand_offset] = Card._3,
                '2' => hand[hand_offset] = Card._2,
                else => unreachable,
            }
            hand_offset += 1;
        } else {
            score_bytes[score_bytes_offset] = char;
            score_bytes_offset += 1;
        }
    }

    return hands;
}
