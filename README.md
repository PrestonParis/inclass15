# API-to-Cloud Trivia Showdown

CSC 4360 In-Class Activity 15 (undergraduate). A Flutter app that fetches five live trivia questions from the Open Trivia Database, shows loading, error, and round states, gives green/red answer feedback, scores each question once, and ends with a **simulated** score sync.

> **Score sync is a simulation.** No instructor endpoint was provided, so the sync button waits one second and shows a confirmation. **No backend request is sent and nothing is saved on a server.** The app shows the JSON payload that a real POST would send, but it does not send it.

## Run

```
flutter pub get
flutter run
```

The app needs an internet connection. Tested on the iOS Simulator (iPhone 17 Pro, iOS 26.5).

```
flutter test                      # unit + widget tests (mocked HTTP, no network)
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/round_test.dart          # live round, saves evidence/E1-E8
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/error_test.dart \
  --dart-define=TRIVIA_URL=https://opentdb.invalid/api.php   # error state, saves evidence/E9
```

`TRIVIA_URL` overrides the endpoint so the error state can be shown without turning off the network.

## How it works

| File | Role |
| --- | --- |
| `lib/trivia_service.dart` | `TriviaService.fetchQuestions()` sends `GET https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple` with a 10 s timeout and validates the response. Every failure becomes a readable `TriviaException`. |
| `lib/question.dart` | `Question.fromJson` maps one result to question text, correct answer, and shuffled options, and decodes HTML entities. |
| `lib/main.dart` | `TriviaShowdownScreen` holds the round state and builds the loading, error, question, and results views. |

### HTTP status vs. API response code

The two checks answer different questions:

1. **HTTP status:** did the request reach the server and come back OK? Anything other than `200` shows `Server error: HTTP <code>`.
2. **`response_code` in the JSON body:** did Open Trivia DB actually have questions for this request? A `200` response can still carry `response_code: 5` (rate limited, at most one request per 5 seconds) or `1` (not enough questions). Only `0` with a non-empty `results` list starts a round.

Malformed JSON and records with missing fields are also errors. The app never shows a partial round.

### States

| State | What the user sees |
| --- | --- |
| Loading | Spinner and "Fetching 5 questions from Open Trivia DB..." |
| Error (network, timeout, HTTP, API code, bad JSON) | Red message and a **Retry** button |
| Question | Progress bar, "Question n of 5", live score, question card, 4 shuffled options |
| Answered | Correct option green, wrong selection red, "Correct!" or "Incorrect. The answer is X.", Next button. Later taps are ignored, so each question scores at most once. |
| Complete | Final score out of the number of loaded questions, **Simulate Score Sync**, payload preview, **Play Again** |

### Changes from the starter

- Moved the request and validation into `TriviaService`, so the widget handles only questions or an error.
- `_restart()` now clears `_error`. In the starter, a single failure left Play Again stuck on the error screen.
- Added a **Retry** button to the error state.
- Entity decoding uses the `html` parser. This covers `&quot;`, `&#039;`, `&amp;`, and others like `&eacute;` and `&ldquo;`, which the starter missed.
- API codes 1, 2, and 5 get specific messages.
- The results screen shows the score payload, with a note that no request is sent.

## Evidence

All images are in `evidence/`. They were captured from the real app on the iOS Simulator against the live API on Nov 11, 2026, by the integration tests above. Question content varies per run.

| File | Shows | Expected | Observed |
| --- | --- | --- | --- |
| `E1_loading.png` | Loading state | Spinner while the request is in flight | Spinner and loading text |
| `E2_question_loaded.png` | First question | Q1 of 5, progress bar, 4 options | As expected |
| `E3_correct_green_q1.png` | Correct answer | Selected option green, score +1 | Green, "Correct!", score 1 |
| `E4_incorrect_red_q2.png` | Wrong answer | Selection red, correct option green, score unchanged | "Red" red, "Yellow" green, score stays 1 |
| `E5_repeat_taps_ignored_q2.png` | Tapping two more options after answering | No change | Same colors, score still 1 |
| `E6_final_score.png` | Round complete | Score out of 5, sync and replay buttons | "Final Score: 2 / 5" |
| `E7a_simulating_sync.png` | Sync in progress | Button disabled, "Simulating sync..." | As expected |
| `E7b_simulated_sync_confirmation.png` | Sync proof | Snackbar says no backend request was sent; payload shown | As expected |
| `E8_replay_new_round.png` | Play Again | New questions, score 0 | New round at Q1, score 0 |
| `E9_error_state_retry.png` | Unreachable host | Readable error, no empty round, Retry | "Could not reach the trivia server..." with Retry |
| `E10_full_round_recording.mp4` | Screen recording of the E1-E8 run | | |

Automated tests (`flutter test`, 11 passing) also cover non-200 status, `response_code` 5, empty results, malformed JSON, network failure, entity decoding, one score per question across a full round, and Retry recovering after an error.

### Known limitations

- Score sync is simulated (see above).
- If the player hits Play Again within about 5 seconds of the last fetch, Open Trivia DB may return `response_code 5`. The app shows a message telling them to wait, and Retry works after a few seconds.
- Nothing is saved locally. Closing the app loses the round.

## Critical thinking (undergraduate)

**1. If connectivity drops after the questions have loaded, what should the player see and be allowed to do?**

They should be able to finish the round. All five questions come in one request at the start, so once the app reaches the question state the round needs no network. Answering, feedback, scoring, and the results screen all run on local state. Interrupting a working round with an error would punish the player for something that doesn't affect it.

The network matters again at two points:
- **Play Again** starts a new fetch. Offline, it goes loading → error ("Could not reach the trivia server...") with Retry, never an empty or half-filled round. This is the same path shown in E9.
- **Score sync**: in this app it is a simulation, so it would still "succeed", which shows why a simulation is not proof of a write. With a real POST, the button should show a failure message, keep the score on screen, and let the player retry. It should not show "synced" until the server confirms the write.

**2. Which trivia data would be worth saving locally, and why is that not a shared leaderboard?**

I would save the player's **personal best score and the last few round results** (score, total, date) with something like `shared_preferences`. That solves a real problem: right now every round is forgotten when the app closes, so a player can't see whether they are improving.

That is still not a leaderboard. Local data lives only on that device and in that install. Nobody else can see it, it disappears if the app is deleted, and the player could edit it, so nothing verifies it. A leaderboard needs one shared store that every player writes to and reads from, with a server that accepts and validates the score. That is the POST endpoint this app only simulates. To avoid confusion, the UI would label it "Your history (this device)" and never use the word leaderboard for it. This is design analysis only; local storage is not implemented.

## Looking ahead to In-Class 16

This app only reads (GET). Activity 16's direct REST write would turn the payload shown on the results screen into a `POST` body sent to a real endpoint, with a JSON content type. The UI would show "synced" only after a success response (e.g. 201) and would show an error with retry on anything else, using the same status-then-body checks as `TriviaService`.
