extends Node


var available: Array[Job] = []
var active: Array[Job] = []
var starknights: Array[Starknight] = []

var _assigning: bool = false


func register(starknight: Starknight) -> void:
	starknights.append(starknight)
	_assign_jobs()


func unregister(starknight: Starknight) -> void:
	starknights.erase(starknight)


func post(job: Job) -> void:
	available.append(job)
	_assign_jobs()


func report_idle() -> void:
	_assign_jobs()


func _assign_jobs() -> void:
	if _assigning:
		return

	_assigning = true
	_run_assignment_pass()
	_assigning = false


func _run_assignment_pass() -> void:
	var idle := starknights.filter(func(starknight: Starknight) -> bool:
		return starknight.is_idle()
	)
	if idle.is_empty():
		return

	for priority in _priorities():
		var jobs := available.filter(func(job: Job) -> bool:
			return job.priority == priority
		)
		_fill_tier(idle, jobs)
		if idle.is_empty():
			return

	for holder in starknights:
		if idle.is_empty():
			return

		var job: Job = holder.assigned_job()
		if job == null:
			continue

		var closest: Starknight = null
		var shortest: float = holder.travel_time(job.target)
		for starknight in idle:
			var travel_time: float = starknight.travel_time(job.target)
			if travel_time < shortest:
				shortest = travel_time
				closest = starknight

		if closest == null:
			continue

		if not closest.assign(job):
			continue
		holder.release()

		idle.erase(closest)
		idle.append(holder)


## The distinct priorities currently posted, highest first.
func _priorities() -> Array:
	var seen: Dictionary[int, bool] = {}
	for job in available:
		seen[job.priority] = true

	var priorities := seen.keys()
	priorities.sort()
	priorities.reverse()
	return priorities


func _fill_tier(idle: Array[Starknight], jobs: Array[Job]) -> void:
	# a Starknight already standing on a job's tile keeps it — this is what lets one
	# re-take the deposit or workshop it just finished instead of being sent away, and
	# nothing further down can steal it since no travel time beats zero
	for starknight in idle.duplicate():
		for job in jobs:
			if starknight.travel_time(job.target) != 0.0:
				continue
			if starknight.assign(job):
				idle.erase(starknight)
				jobs.erase(job)
				available.erase(job)
				active.append(job)
			break

	# the rest go to their closest idle Starknight, shuffled so that a far-flung job
	# still takes its turn rather than forever losing out to nearer ones
	jobs.shuffle()
	for job in jobs:
		if idle.is_empty():
			return

		var closest: Starknight = null
		var shortest := INF
		for starknight in idle:
			var travel_time: float = starknight.travel_time(job.target)
			if travel_time < shortest:
				shortest = travel_time
				closest = starknight

		if closest == null:
			continue
		if not closest.assign(job):
			continue

		idle.erase(closest)
		available.erase(job)
		active.append(job)


func complete(job: Job) -> void:
	# Retire the job before running its handler: a handler that adds to the
	# Stockpile can re-enter cancel_jobs_on_tile (e.g. a finished craft completes a
	# challenge), and a still-active job would then fire on_cancel and double-refund.
	active.erase(job)
	if job.on_complete.is_valid():
		job.on_complete.call()


## Cancel one job wherever it currently sits. Cancelling by tile takes out everything
## posted there, which is too blunt once more than one thing can be posted on the same
## tile — a Workshop dropping its own craft job must leave research on that tile alone.
func cancel(job: Job) -> void:
	var was_active := job in active

	if not was_active and job not in available:
		return

	if was_active:
		active.erase(job)
	else:
		available.erase(job)

	if job.on_cancel.is_valid():
		job.on_cancel.call()

	if was_active:
		job.abort()


func cancel_jobs_on_tile(tile: HexTile) -> void:
	var filter := func(job: Job) -> bool:
		return job.target == tile

	for job in available.filter(filter):
		cancel(job)

	for job in active.filter(filter):
		cancel(job)
