# Plan: poprawki z listy „niskie"

Źródło: code review całości (punkty o niskiej wadze). Punkty 1-3 ze średniej wagi są już naprawione (commit `cd545aa`).

Weryfikacja po każdej fazie: `make format && make lint && make test-package`. Na końcu `make test-app`. Commit po każdej fazie.

## Faza A: spójność domeny i sync (`LocalStorage`, `SyncEngine`)

**A1. `undoDelivery` sprawdza aktywną zmianę**
- W `LocalStore+TaskMutations.swift` `undoDelivery` wymaga `activeShiftRecord()` i `record.shiftID == shift.id`. Błędy: `shiftNotActive` i `taskNotInActiveShift`. Sprawdzenie idzie po maszynie stanów, przed oknem Undo.
- `endShift` zostaje bez zmian. Zadanie w oknie Undo go nie blokuje, a po zakończeniu zmiany Undo jest odrzucane.
- Test w `TaskTransitionTests`: `markDelivered`, potem `endShift`, potem `undoDelivery` rzuca `shiftNotActive`, a zadanie zostaje `delivered`.

**A2. Wyścig w `wakeFired`**
- W `SyncActor.swift` dodaję licznik generacji (`wakeGeneration`). `scheduleWake` zwiększa go i przekazuje do taska. `wakeFired(generation:)` kończy się od razu, gdy generacja jest nieaktualna, i nie zeruje `wakeTask`.
- Test w `SyncSchedulingTests`: po sekwencji „wake odpala, w tym samym czasie podmiana jobu" jest dokładnie jeden `pendingSleeperCount`, a po `stop()` zero. Deterministyczne odtworzenie wyścigu może się nie udać. Wtedy zostaje test niezmiennika po `stop()` i poprawka w kodzie.

## Faza B: UI i obsługa błędów (`FeatureDashboard`, `FeatureDelivery`)

**B1. Blokada podwójnego tapnięcia**
- `TaskDetailsModel` dostaje `private(set) var isPerformingAction`. `perform` zwraca `false` bez ustawiania `failure`, gdy poprzednia akcja jeszcze trwa. Przyciski dostają `.disabled(model.isPerformingAction)`.
- Ten sam wzorzec w `ShiftCardModel` (start i koniec zmiany).
- `completeDelivery` i `commitDeliveryIfNeeded` przechodzą przez ten sam guard. Jeśli inna akcja trwa, `finish()` wywoła ona albo zmieni to status zadania. Nie ma ryzyka, że ekran zostanie niezamknięty.
- Testy na `FakeTaskRepository`: dwa równoległe `startDelivery` dają jedno wywołanie repozytorium i brak `failure`. Analogicznie dla `ShiftCardModel`.

**B2. Konkretne komunikaty błędów**
- W każdym module jest rozszerzenie `RepositoryError` z lokalizowanym tekstem. Modułowe katalogi i duplikacja są zgodne z planem implementacji §4.10. Używam wyczerpującego `switch` bez `default`, żeby nowy case wymuszał uzupełnienie.
- `FeatureDashboard`: `shiftHasTaskInTransit`, `shiftNotActive`, `taskNotInActiveShift`, reszta to komunikat ogólny.
- `FeatureDelivery`: `anotherTaskInTransit`, `undoWindowClosed`, `invalidTransition`, `taskNotInActiveShift`, `exceptionDetailsRequired`, reszta to komunikat ogólny.
- Alerty pokazują ten tekst zamiast stałego komunikatu. Klucze w `Localizable.xcstrings` obu modułów. Testy: po jednym teście mapowania na moduł (kilka przypadków).

**B3. Szczegóły zadania po zniknięciu zadania**
- W `TaskDetailsModel.run` pamiętam, czy zadanie już raz się pojawiło (`hasLoadedTask`). Gdy strumień potem wyemituje `nil` (reset danych), model woła `finish()`. Ekran zamyka się zamiast kręcić spinnerem w nieskończoność. Nie dotykam routera.
- Test: wysłać zadanie, potem `nil`, i sprawdzić, że `onFinish` wywołano raz.

## Faza C: czystość kodu i konfiguracja

**C1. Sprzątanie**
- `AppRouter`: usuwam nieużywane `historyPath` i `settingsPath`. Stosy w `MainTabView` dla History i Settings tworzę bez `path:`.
- `HistoryModel`: usuwam martwe `?? task.assignedAt` i `?? .distantPast`. Filtr zamieniam na `compactMap`, który zwraca zadanie razem z `completedAt`.
- `AppEnvironment`: argument `--ui-testing` jest honorowany tylko pod `#if DEBUG`. Najpierw sprawdzam, że `make test-app` buduje Debug.

**C2. CI**
- Job `lint` w `.github/workflows/ci.yml` dostaje ten sam `DEVELOPER_DIR` co job `test`, a `swift-format` jest tej samej wersji co lokalnie.

## Faza D: higiena testów

- **Ostrzeżenia sqlite „vnode unlinked while in use":** w `SyncResilienceTests` i `DiskPersistenceTests` zamykam użycie kontenera w osobnym zakresie (`do {}` albo funkcja pomocnicza). Pliki store'u usuwam dopiero po zwolnieniu kontenera i `LocalStore`, a nie przez `defer` w tym samym zakresie. Kryterium: brak `BUG IN CLIENT OF libsqlite3` w logu `make test-package`.
- **`StreamBroadcaster.update`:** odczyt, transformacja i zapis w jednym `withLock`. `send` poza blokadą, żeby nie yieldować pod mutexem.
- **`eventually`:** po anulowaniu zwraca `false` zamiast pętlić do timeoutu (`guard !Task.isCancelled`).

## Faza E: synchronizacja dokumentacji

W `Docs/implementationPlan.md`:
- status faz i checkboxy w §5 zgodne ze stanem kodu;
- §4.3: `treatAllWarnings` jest zastąpione flagami w `Makefile` (opis ze spike'a 4), bez fragmentu, którego nie ma w `Package.swift`;
- §4.1, §4.5, Faza 4a: kontener tworzy `AppNavigation` (leniwie, w `.task` w `RootView`), nie host;
- §4.4: `SyncError.cancelled` i `.storageFailure`;
- §4.6: semantyka drainu po poprawkach (blokada per `taskID`, ponawianie nieudanych jobów tylko przez zewnętrzne triggery, pomijanie nieczytelnych rekordów outboxu).

## Kolejność i commity

1. A1 + A2 (jeden commit, zmiany w warstwie danych i sync).
2. B1 + B2 + B3 (jeden commit na UI).
3. C1 + C2.
4. D.
5. E.

Ryzyko: najwyższe w A2 (współbieżność) i B1 (zmiana zachowania przycisków pod testami UI). Dlatego po B uruchamiam `make test-app`.
