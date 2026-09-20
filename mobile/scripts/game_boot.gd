extends Node

func _ready() -> void:
	print("boot ok locale: ", TranslationServer.get_locale())
