c = get_config()

# Stateless/multi-user friendly: avoid SQLite history file locking when multiple
# kernels start concurrently (common in containers).
# Keeping history in-memory also avoids persisting per-user state to disk.
c.HistoryManager.hist_file = ':memory:'
