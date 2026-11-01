-- Tabela única da telemetria (D1 / SQLite). Sem IP, sem cabeçalhos, só o dia do envio.
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  install_id TEXT NOT NULL,
  event TEXT NOT NULL,
  app TEXT NOT NULL,
  platform TEXT NOT NULL,
  day TEXT NOT NULL,
  body TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS events_install ON events (install_id);
CREATE INDEX IF NOT EXISTS events_event_day ON events (event, day);
