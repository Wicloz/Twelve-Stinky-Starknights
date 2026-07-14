extends Node


var available: Array[Job] = []
var active: Array[Job] = []


func post(job: Job) -> void:
	available.append(job)


func candidates() -> Array[Job]:
	if available.is_empty():
		return []

	var best_priority := -INF
	for job in available:
		best_priority = max(best_priority, job.priority)

	var best_jobs: Array[Job] = []
	for job in available:
		if job.priority == best_priority:
			best_jobs.append(job)

	return best_jobs


func is_available(job: Job) -> bool:
	return available.has(job)


func claim(job: Job) -> bool:
	if not available.has(job):
		return false

	available.erase(job)
	active.append(job)
	return true


func complete(job: Job) -> void:
	if job.on_complete.is_valid():
		job.on_complete.call()
	active.erase(job)


func abandon(job: Job) -> void:
	active.erase(job)
	available.append(job)


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
