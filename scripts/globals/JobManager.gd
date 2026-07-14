extends Node


var available: Array[Job] = []
var active: Array[Job] = []
var starknights: Array[Starknight] = []


func register(starknight: Starknight) -> void:
	starknights.append(starknight)


func unregister(starknight: Starknight) -> void:
	starknights.erase(starknight)


func post(job: Job) -> void:
	available.append(job)


func _process(_delta: float) -> void:
	_assign_jobs()


func _assign_jobs() -> void:
	if available.is_empty():
		return

	var idle := starknights.filter(func(starknight: Starknight) -> bool: return starknight.is_idle())
	if idle.is_empty():
		return

	for job in _queue():
		if idle.is_empty():
			return

		var closest: Starknight = null
		var shortest := INF
		for starknight in idle:
			var travel_time: float = starknight.travel_time(job.target)
			if travel_time < shortest:
				shortest = travel_time
				closest = starknight

		# nobody can reach it from where they stand — leave it for another time
		if closest == null:
			continue

		if not closest.assign(job):
			continue

		idle.erase(closest)
		available.erase(job)
		active.append(job)


func _queue() -> Array[Job]:
	var by_priority: Dictionary[int, Array] = {}
	for job in available:
		if not by_priority.has(job.priority):
			by_priority[job.priority] = []
		by_priority[job.priority].append(job)

	var priorities := by_priority.keys()
	priorities.sort()
	priorities.reverse()

	var queue: Array[Job] = []
	for priority in priorities:
		var jobs: Array = by_priority[priority]
		jobs.shuffle()
		queue.append_array(jobs)

	return queue


func complete(job: Job) -> void:
	if job.on_complete.is_valid():
		job.on_complete.call()
	active.erase(job)


func cancel_jobs_on_tile(tile: HexTile) -> void:
	var filter := func(job: Job) -> bool:
		return job.target == tile

	for job in available.filter(filter):
		if job.on_cancel.is_valid():
			job.on_cancel.call()
		available.erase(job)

	for job in active.filter(filter):
		if job.on_cancel.is_valid():
			job.on_cancel.call()
		job.abort()
		active.erase(job)
