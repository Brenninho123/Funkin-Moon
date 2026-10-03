#include <cstdio>
#include <vector>

#include "../src/rating.hpp"

using namespace moon;

static int failures = 0;
static int checks = 0;

static void check(const char *name, bool condition)
{
  checks++;

  if (condition) return;

  failures++;
  std::printf("FAIL: %s\n", name);
}

static RatingEntry entry(int rating, int rounds, int rank)
{
  RatingEntry value;

  value.rating = rating;
  value.ratedRounds = rounds;
  value.rank = rank;

  return value;
}

int main()
{
  check("equal players expect one half", std::abs(expectedScore(1000, 1000) - 0.5) < 1e-9);
  check("the stronger player expects more", expectedScore(1400, 1000) > 0.9 && expectedScore(1000, 1400) < 0.1);
  check("expectations add up to one", std::abs(expectedScore(1234, 987) + expectedScore(987, 1234) - 1.0) < 1e-9);
  check("new players move fast", kFactor(0) == ProvisionalK && kFactor(ProvisionalRounds - 1) == ProvisionalK);
  check("settled players move slowly", kFactor(ProvisionalRounds) == SettledK && kFactor(500) == SettledK);

  std::vector<int> pair = ratingDeltas({entry(1000, 0, 1), entry(1000, 0, 2)});

  check("two equal new players swap twenty points", pair[0] == 20 && pair[1] == -20);

  std::vector<int> settled = ratingDeltas({entry(1000, 50, 1), entry(1000, 50, 2)});

  check("two equal settled players swap twelve points", settled[0] == 12 && settled[1] == -12);

  std::vector<int> upset = ratingDeltas({entry(1000, 50, 1), entry(1400, 50, 2)});

  check("an upset pays more than an expected win", upset[0] > 20 && upset[1] < -20);

  std::vector<int> expected = ratingDeltas({entry(1400, 50, 1), entry(1000, 50, 2)});

  check("an expected win pays little", expected[0] > 0 && expected[0] < 4 && expected[1] < 0 && expected[1] > -4);

  std::vector<int> tie = ratingDeltas({entry(1000, 50, 1), entry(1000, 50, 1)});

  check("a tie between equals changes nothing", tie[0] == 0 && tie[1] == 0);

  std::vector<int> tieUnequal = ratingDeltas({entry(1200, 50, 1), entry(1000, 50, 1)});

  check("a tie costs the stronger player", tieUnequal[0] < 0 && tieUnequal[1] > 0);

  std::vector<int> four = ratingDeltas({entry(1000, 0, 1), entry(1000, 0, 2), entry(1000, 0, 3), entry(1000, 0, 4)});

  check("first place of four gains most", four[0] > four[1] && four[1] > four[2] && four[2] > four[3]);
  check("the middle of an even field breaks even by symmetry", four[1] == -four[2] || std::abs(four[1] + four[2]) <= 1);
  check("the total stays near zero", std::abs(four[0] + four[1] + four[2] + four[3]) <= 2);
  check("one player has no one to play", ratingDeltas({entry(1000, 0, 1)})[0] == 0 && ratingDeltas({}).empty());

  std::vector<int> floor = ratingDeltas({entry(MinimumRating, 50, 2), entry(1000, 50, 1)});

  check("the rating never goes under the floor", floor[0] == 0);

  std::vector<int> ceiling = ratingDeltas({entry(MaximumRating, 50, 1), entry(MaximumRating - 100, 50, 2)});

  check("the rating never goes over the ceiling", MaximumRating + ceiling[0] <= MaximumRating);

  check("the average of nothing is the starting rating", averageRating({}) == StartingRating);
  check("the average is the mean", averageRating({1000, 1200, 1100}) == 1100);
  check("match quality is the distance", matchQuality(1000, 1200) == 200 && matchQuality(1300, 1100) == 200);

  std::printf(failures == 0 ? "all %d checks passed\n" : "%d checks, some failed\n", checks);

  return failures == 0 ? 0 : 1;
}
