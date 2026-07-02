# Lua scripts for first-writer-wins task state transitions.
#
# A task key is moved to a terminal state only if it can still be removed from its source in the same atomic step.
# The first actor to remove a key from its source decides the state of the task,
# and the transition of the losing actor is discarded.
# This prevents a task from being recorded in two states at once,
# for example when a live worker is wrongly declared lost while it is finishing a task.
#
# The move scripts take the source at KEYS[1], the destination at KEYS[2],
# and the task keys as ARGV.
# They return the keys that were actually moved.

# move keys from the running set to the finished list
lua_move_set_to_list = "
local moved = {}
for i = 1, #ARGV do
  if redis.call('SREM', KEYS[1], ARGV[i]) == 1 then
    redis.call('RPUSH', KEYS[2], ARGV[i])
    moved[#moved + 1] = ARGV[i]
  end
end
return moved
"

# move keys from the running set to the failed set
lua_move_set_to_set = "
local moved = {}
for i = 1, #ARGV do
  if redis.call('SREM', KEYS[1], ARGV[i]) == 1 then
    redis.call('SADD', KEYS[2], ARGV[i])
    moved[#moved + 1] = ARGV[i]
  end
end
return moved
"

# move keys from the pending list to the failed set
lua_move_list_to_set = "
local moved = {}
for i = 1, #ARGV do
  if redis.call('LREM', KEYS[1], 1, ARGV[i]) == 1 then
    redis.call('SADD', KEYS[2], ARGV[i])
    moved[#moved + 1] = ARGV[i]
  end
end
return moved
"

# move the task at KEYS[3] from the pending list (KEYS[1]) to the running set (KEYS[2])
# and record the serialized worker id (ARGV[1]) on the task hash
lua_mark_running = "
if redis.call('LREM', KEYS[1], 1, KEYS[3]) == 1 then
  redis.call('SADD', KEYS[2], KEYS[3])
  redis.call('HSET', KEYS[3], 'worker_id', ARGV[1])
  return 1
end
return 0
"
