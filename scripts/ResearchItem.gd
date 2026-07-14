class_name ResearchItem


enum State {
    LOCKED,
    AVAILABLE,
    RESEARCHING,
    COMPLETED,
}

var display_name: String
var description: String
var texture: Texture2D

var cost: Dictionary[Stockpile.ItemType, int] = {}
var work: float

var research_at: Script
var slot: int
var prerequisites: Array[ResearchItem] = []

var on_complete: Callable
var state: State = State.LOCKED
