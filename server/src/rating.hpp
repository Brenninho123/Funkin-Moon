#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

namespace moon
{
constexpr int StartingRating = 1000;
constexpr int MinimumRating = 100;
constexpr int MaximumRating = 4000;
constexpr int ProvisionalRounds = 10;
constexpr int ProvisionalK = 40;
constexpr int SettledK = 24;

struct RatingEntry
{
  int rating = StartingRating;
  int ratedRounds = 0;
  int rank = 1;
};

inline double expectedScore(double ratingA, double ratingB)
{
  return 1.0 / (1.0 + std::pow(10.0, (ratingB - ratingA) / 400.0));
}

inline int kFactor(int ratedRounds)
{
  return ratedRounds < ProvisionalRounds ? ProvisionalK : SettledK;
}

inline std::vector<int> ratingDeltas(const std::vector<RatingEntry>& entries)
{
  std::vector<int> deltas(entries.size(), 0);

  if (entries.size() < 2) return deltas;

  double opponents = static_cast<double>(entries.size() - 1);

  for (size_t i = 0; i < entries.size(); i++)
  {
    double total = 0.0;

    for (size_t j = 0; j < entries.size(); j++)
    {
      if (i == j) continue;

      double actual = entries[i].rank < entries[j].rank ? 1.0 : (entries[i].rank == entries[j].rank ? 0.5 : 0.0);

      total += actual - expectedScore(entries[i].rating, entries[j].rating);
    }

    double raw = kFactor(entries[i].ratedRounds) * total / opponents;
    int delta = static_cast<int>(std::lround(raw));
    int updated = std::max(MinimumRating, std::min(MaximumRating, entries[i].rating + delta));

    deltas[i] = updated - entries[i].rating;
  }

  return deltas;
}

inline int averageRating(const std::vector<int>& ratings)
{
  if (ratings.empty()) return StartingRating;

  int64_t sum = 0;

  for (int rating : ratings) sum += rating;

  return static_cast<int>(sum / static_cast<int64_t>(ratings.size()));
}

inline int matchQuality(int playerRating, int roomAverage)
{
  return std::abs(playerRating - roomAverage);
}
}
