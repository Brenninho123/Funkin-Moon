#include <algorithm>
#include <cmath>
#include <functional>
#include <iostream>
#include <string>
#include <vector>

enum class NoteDirection
{
  LEFT,
  DOWN,
  UP,
  RIGHT
};

enum class Judgement
{
  SICK,
  GOOD,
  BAD,
  SHIT,
  MISSED
};

struct ChartNote
{
  double timeMs = 0.0;
  int lane = 0;
  double sustainLengthMs = 0.0;
  bool hit = false;
  bool missed = false;
};

struct JudgementTallies
{
  int sick = 0;
  int good = 0;
  int bad = 0;
  int shit = 0;
  int missed = 0;
  int combo = 0;
  int maxCombo = 0;
};

struct JudgementWindow
{
  double sickMs = 45.0;
  double goodMs = 90.0;
  double badMs = 135.0;
  double shitMs = 160.0;
};

class Conductor
{
public:
  double bpm = 100.0;
  double songPosition = 0.0;

  double crochet() const
  {
    return 60000.0 / bpm;
  }

  double stepCrochet() const
  {
    return crochet() / 4.0;
  }

  int currentStep() const
  {
    return static_cast<int>(std::floor(songPosition / stepCrochet()));
  }

  int currentBeat() const
  {
    return static_cast<int>(std::floor(songPosition / crochet()));
  }
};

class PlayState
{
public:
  static PlayState *instance;

  static constexpr double MAX_HEALTH = 2.0;

  std::string songName;
  std::string currentDifficulty = "normal";
  std::string currentVariation = "default";
  double playbackRate = 1.0;
  double health = 1.0;
  int songScore = 0;
  int deathCounter = 0;
  bool isPracticeMode = false;
  bool isBotPlayMode = false;
  bool paused = false;
  bool songEnded = false;

  Conductor conductor;
  JudgementTallies tallies;
  JudgementWindow judgementWindow;

  std::vector<ChartNote> notes;

  std::function<void(Judgement, const ChartNote &)> onNoteJudged = [](Judgement, const ChartNote &) {};
  std::function<void(const ChartNote &)> onNoteMissed = [](const ChartNote &) {};
  std::function<void()> onSongEnd = [] {};
  std::function<void()> onPlayerDeath = [] {};
  std::function<void(const std::string &)> onValidationError = [](const std::string &) {};

  bool dead = false;

  PlayState()
  {
    instance = this;
  }

  PlayState(const PlayState &) = delete;
  PlayState &operator=(const PlayState &) = delete;

  ~PlayState()
  {
    if (instance == this) instance = nullptr;
  }

  void loadChart(std::vector<ChartNote> chartNotes)
  {
    notes = std::move(chartNotes);

    std::stable_sort(notes.begin(), notes.end(), [](const ChartNote &a, const ChartNote &b) { return a.timeMs < b.timeMs; });

    missScanStart = 0;
  }

  void update(double elapsedMs)
  {
    if (paused || dead) return;

    conductor.songPosition += elapsedMs * playbackRate;

    processMisses();

    validateCount++;

    if (validateCount >= validateEveryNTicks)
    {
      validateCount = 0;
      runInvariantChecks();
    }

    if (!songEnded && allNotesResolved())
    {
      songEnded = true;
      onSongEnd();
    }
  }

  bool hitNote(int lane, double inputTimeMs)
  {
    if (paused || dead || songEnded) return false;

    ChartNote *closest = findClosestUnresolvedNote(lane, inputTimeMs);

    if (closest == nullptr) return false;

    double delta = std::fabs(inputTimeMs - closest->timeMs);

    Judgement judgement = Judgement::MISSED;

    if (delta <= judgementWindow.sickMs)
    {
      judgement = Judgement::SICK;
    }
    else if (delta <= judgementWindow.goodMs)
    {
      judgement = Judgement::GOOD;
    }
    else if (delta <= judgementWindow.badMs)
    {
      judgement = Judgement::BAD;
    }
    else if (delta <= judgementWindow.shitMs)
    {
      judgement = Judgement::SHIT;
    }
    else
    {
      return false;
    }

    closest->hit = true;
    applyJudgement(judgement);
    onNoteJudged(judgement, *closest);

    return true;
  }

  double healthPercent() const
  {
    return MAX_HEALTH > 0.0 ? (health / MAX_HEALTH) * 100.0 : 0.0;
  }

  double accuracy() const
  {
    int totalJudged = tallies.sick + tallies.good + tallies.bad + tallies.shit + tallies.missed;

    if (totalJudged == 0) return 100.0;

    double weightedScore = tallies.sick * 1.0 + tallies.good * 0.7 + tallies.bad * 0.4 + tallies.shit * 0.2;

    return (weightedScore / totalJudged) * 100.0;
  }

  std::vector<std::string> validate() const
  {
    std::vector<std::string> issues;

    if (!(conductor.bpm > 0.0)) issues.push_back("Conductor BPM must be greater than zero.");

    if (std::isnan(health) || std::isinf(health)) issues.push_back("Health is NaN or infinite.");

    if (health < 0.0 || health > MAX_HEALTH)
    {
      issues.push_back("Health is outside the valid range [0, " + std::to_string(MAX_HEALTH) + "].");
    }

    if (std::isnan(conductor.songPosition) || std::isinf(conductor.songPosition)) issues.push_back("Song position is NaN or infinite.");

    if (conductor.songPosition < 0.0) issues.push_back("Song position is negative.");

    if (tallies.combo > tallies.maxCombo) issues.push_back("Current combo exceeds max combo.");

    if (tallies.combo < 0 || tallies.maxCombo < 0) issues.push_back("Combo counters are negative.");

    if (songScore < 0) issues.push_back("Song score is negative.");

    if (playbackRate <= 0.0) issues.push_back("Playback rate must be greater than zero.");

    for (std::size_t i = 0; i < notes.size(); i++)
    {
      const auto &note = notes[i];

      if (std::isnan(note.timeMs) || std::isinf(note.timeMs))
      {
        issues.push_back("Note #" + std::to_string(i) + " has a NaN or infinite time.");
      }

      if (note.timeMs < 0.0) issues.push_back("Note #" + std::to_string(i) + " has a negative time.");

      if (note.lane < 0 || note.lane > 3)
      {
        issues.push_back("Note #" + std::to_string(i) + " has an out-of-range lane (" + std::to_string(note.lane) + ").");
      }

      if (note.sustainLengthMs < 0.0) issues.push_back("Note #" + std::to_string(i) + " has a negative sustain length.");

      if (note.hit && note.missed) issues.push_back("Note #" + std::to_string(i) + " is marked as both hit and missed.");

      if (i > 0 && notes[i - 1].timeMs > note.timeMs) issues.push_back("Chart is not sorted by time at index " + std::to_string(i) + ".");
    }

    int totalResolved = 0;

    for (const auto &note : notes)
    {
      if (note.hit || note.missed) totalResolved++;
    }

    int totalTallied = tallies.sick + tallies.good + tallies.bad + tallies.shit + tallies.missed;

    if (totalTallied != totalResolved)
    {
      issues.push_back(
        "Judgement tally total (" + std::to_string(totalTallied) + ") does not match resolved note count (" + std::to_string(totalResolved) + ")."
      );
    }

    return issues;
  }

  bool isHealthy() const
  {
    return validate().empty();
  }

private:
  std::size_t missScanStart = 0;
  int validateCount = 0;
  int validateEveryNTicks = 60;
  bool lastValidationOk = true;

  void applyJudgement(Judgement judgement)
  {
    switch (judgement)
    {
      case Judgement::SICK:
        tallies.sick++;
        tallies.combo++;
        health = std::min(MAX_HEALTH, health + 0.02);
        songScore += 350;
        break;
      case Judgement::GOOD:
        tallies.good++;
        tallies.combo++;
        health = std::min(MAX_HEALTH, health + 0.01);
        songScore += 200;
        break;
      case Judgement::BAD:
        tallies.bad++;
        tallies.combo++;
        songScore += 100;
        break;
      case Judgement::SHIT:
        tallies.shit++;
        tallies.combo = 0;
        health = std::max(0.0, health - 0.05);
        songScore += 50;
        break;
      case Judgement::MISSED:
        break;
    }

    tallies.maxCombo = std::max(tallies.maxCombo, tallies.combo);

    if (health <= 0.0 && !isPracticeMode) triggerDeath();
  }

  void processMisses()
  {
    while (missScanStart < notes.size() && (notes[missScanStart].hit || notes[missScanStart].missed))
    {
      missScanStart++;
    }

    for (std::size_t i = missScanStart; i < notes.size() && !dead; i++)
    {
      ChartNote &note = notes[i];

      if (note.hit || note.missed) continue;

      if (conductor.songPosition <= note.timeMs + judgementWindow.shitMs) break;

      note.missed = true;
      tallies.missed++;
      tallies.combo = 0;
      health = std::max(0.0, health - 0.075);

      onNoteMissed(note);

      if (health <= 0.0 && !isPracticeMode) triggerDeath();
    }
  }

  ChartNote *findClosestUnresolvedNote(int lane, double inputTimeMs)
  {
    ChartNote *closest = nullptr;
    double closestDelta = judgementWindow.shitMs + 1.0;

    for (auto &note : notes)
    {
      if (note.lane != lane || note.hit || note.missed) continue;

      double delta = std::fabs(inputTimeMs - note.timeMs);

      if (delta < closestDelta)
      {
        closestDelta = delta;
        closest = &note;
      }
    }

    return closest;
  }

  bool allNotesResolved() const
  {
    if (notes.empty()) return false;

    for (const auto &note : notes)
    {
      if (!note.hit && !note.missed) return false;
    }

    return true;
  }

  void triggerDeath()
  {
    if (dead) return;

    dead = true;
    deathCounter++;
    onPlayerDeath();
  }

  void runInvariantChecks()
  {
    std::vector<std::string> issues = validate();

    if (issues.empty())
    {
      lastValidationOk = true;
      return;
    }

    if (lastValidationOk)
    {
      for (const auto &issue : issues) onValidationError(issue);
    }

    lastValidationOk = false;
  }
};

PlayState *PlayState::instance = nullptr;

static std::string judgementName(Judgement judgement)
{
  switch (judgement)
  {
    case Judgement::SICK:
      return "SICK";
    case Judgement::GOOD:
      return "GOOD";
    case Judgement::BAD:
      return "BAD";
    case Judgement::SHIT:
      return "SHIT";
    case Judgement::MISSED:
      return "MISSED";
    default:
      return "UNKNOWN";
  }
}

int main()
{
  PlayState playState;

  playState.songName = "Test Song";
  playState.conductor.bpm = 120.0;

  playState.onNoteJudged = [](Judgement judgement, const ChartNote &note)
  {
    std::cout << "Judged note at " << note.timeMs << "ms on lane " << note.lane << ": " << judgementName(judgement) << "\n";
  };

  playState.onNoteMissed = [](const ChartNote &note)
  {
    std::cout << "Missed note at " << note.timeMs << "ms on lane " << note.lane << "\n";
  };

  playState.onValidationError = [](const std::string &issue) { std::cerr << "PlayState validation error: " << issue << "\n"; };

  playState.onPlayerDeath = [] { std::cout << "Player died.\n"; };

  playState.onSongEnd = [] { std::cout << "Song ended.\n"; };

  std::vector<ChartNote> chart = {
    {500.0, 0, 0.0},
    {1000.0, 1, 0.0},
    {1500.0, 2, 0.0},
    {2000.0, 3, 0.0}
  };

  playState.loadChart(chart);

  double elapsedPerTick = 16.0;
  double simulatedTime = 0.0;

  while (!playState.songEnded && !playState.dead && simulatedTime < 5000.0)
  {
    playState.update(elapsedPerTick);
    simulatedTime += elapsedPerTick;

    if (std::fabs(simulatedTime - 500.0) < elapsedPerTick) playState.hitNote(0, simulatedTime);
    if (std::fabs(simulatedTime - 1000.0) < elapsedPerTick) playState.hitNote(1, simulatedTime);
  }

  std::vector<std::string> issues = playState.validate();

  if (issues.empty())
  {
    std::cout << "\nPlayState OK: no errors detected.\n";
  }
  else
  {
    std::cout << "\nPlayState reported " << issues.size() << " issue(s):\n";

    for (const auto &issue : issues) std::cout << "  - " << issue << "\n";
  }

  std::cout << "Score: " << playState.songScore << ", Accuracy: " << playState.accuracy() << "%, Health: " << playState.healthPercent()
            << "%\n";

  return issues.empty() ? 0 : 1;
}
