# Loops

Starten mit dem `CronCreate` Tool. Einmal am Anfang der Session `list_tasks` aufrufen um den Stand zu checken — danach im Loop ausschliesslich `get_instructions` nutzen (offene Tasks werden darueber als Instruction ausgeliefert). Kein `git push` aus der Sandbox — `scripts/autopush.sh` uebernimmt den Remote-Sync.

## Loop 1 — Task Agent (every 1m)

```json
// CronCreate
{
  "cron": "*/1 * * * *",
  "recurring": true,
  "prompt": "Ruf get_instructions fuer das planning_poker project ab (NUR get_instructions, kein list_tasks im Loop): Reagiere auf Chat-Nachrichten. Arbeite am naechsten Task in einem opus subagent mit run_in_background=true um waehrend der Arbeit weiter auf Nachrichten reagieren zu koennen. Starte keine weiteren Task-Bearbeitungen parallel. Changes immer mit \"mix precommit\" und \"scripts/e2e.sh\" verifizieren. Commit lokal \u2014 KEIN git push aus der Sandbox, scripts/autopush.sh uebernimmt das. Tasks mit complete_task abschliessen und dabei den comment-Parameter nutzen um deine Aenderungen zusammenzufassen (als Kontext fuer Folge-Tasks). Bei complete_task auch commit_ref (git rev-parse --short HEAD) und commit_url (aus git remote origin URL + Full-SHA gebaut, z.B. https://github.com/org/repo/commit/<sha>) mitgeben. Wenn du einen Task nicht zufriedenstellend loesen kannst, update_task auf status \"failed\" mit comment warum. Falls sich aus der Bearbeitung groessere Folge-Tasks ergeben, erstelle diese als Draft mit create_task."
}
```

## Loop 2 — Context Compaction (every 30m)

```json
// CronCreate
{
  "cron": "*/30 * * * *",
  "recurring": true,
  "prompt": "Run scripts/sandbox-signal.sh compact"
}
```
