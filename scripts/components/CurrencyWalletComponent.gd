class_name CurrencyWalletComponent
extends Node
## One wallet can later support multiple currency IDs. This first iteration
## intentionally exposes only Breach Scrip to keep trade readable.

signal balance_changed(balance: int)

@export var currency_id: StringName = &"breach_scrip"
@export var currency_name := "Breach Scrip"
@export var balance := 0


func can_spend(amount: int) -> bool:

	return amount >= 0 and balance >= amount


func spend(amount: int) -> bool:

	if not can_spend(amount):
		return false
	balance -= amount
	balance_changed.emit(balance)
	return true


func credit(amount: int) -> void:

	if amount <= 0:
		return
	balance += amount
	balance_changed.emit(balance)
