ALTER TABLE sync_logs
  ADD COLUMN last_progress_at TIMESTAMP NULL AFTER finished_at;
