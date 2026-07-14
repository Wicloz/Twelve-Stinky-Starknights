class_name ExtractionBuilding
extends Building


var _has_active_job: bool = false


func _process(delta: float) -> void:
    if _under_construction or _has_active_job:
        return

    _has_active_job = true

    var job = Job.new()
    job.target = tile
    job.priority = 2
    job.duration = tile.HARVEST_DURATION / 10
    job.on_complete = _on_mine_complete
    job.on_cancel = _on_mine_aborted
    JobManager.post(job)


func _on_mine_complete() -> void:
    Stockpile.add(tile.deposit, tile.HARVEST_AMOUNT)
    _has_active_job = false


func _on_mine_aborted() -> void:
    _has_active_job = false
