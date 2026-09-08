class_name MerchantTradeComponent
extends Node
## Transaction coordinator between any two containers and their wallets.

signal trade_completed(message: String)
signal trade_failed(message: String)

var stock: ItemContainerComponent
var wallet: CurrencyWalletComponent
var buy_markup := 1.25
var sell_ratio := 0.55


func setup(stock_container: ItemContainerComponent, currency_wallet: CurrencyWalletComponent) -> void:

	stock = stock_container
	wallet = currency_wallet


func buy_to(player_inventory: ItemContainerComponent, player_wallet: CurrencyWalletComponent, stock_index: int) -> bool:

	if stock == null or player_inventory == null or player_wallet == null or stock_index < 0 or stock_index >= stock.slots.size():
		return _fail("Trade unavailable")
	var stack := stock.slots[stock_index]
	if stack == null:
		return _fail("Item is no longer available")
	var cost := price_for(stack.definition, stack.quantity, true)
	if not player_wallet.can_spend(cost):
		return _fail("Need %d Breach Scrip" % cost)
	if not player_inventory.can_accept_stack(stack):
		return _fail("Your backpack cannot carry that")
	var moved := stock.move_slot_to(player_inventory, stock_index)
	if not moved:
		return _fail("Could not transfer item")
	player_wallet.spend(cost)
	if wallet:
		wallet.credit(cost)
	trade_completed.emit("BOUGHT %s  -%d SCRIP" % [stack.definition.display_name.to_upper(), cost])
	return true


func sell_from(player_inventory: ItemContainerComponent, player_wallet: CurrencyWalletComponent, player_index: int) -> bool:

	if stock == null or player_inventory == null or player_wallet == null or player_index < 0 or player_index >= player_inventory.slots.size():
		return _fail("Trade unavailable")
	var stack := player_inventory.slots[player_index]
	if stack == null:
		return _fail("Item is no longer available")
	var payment := price_for(stack.definition, stack.quantity, false)
	if wallet and not wallet.can_spend(payment):
		return _fail("Merchant has no scrip left")
	if not stock.can_accept_stack(stack):
		return _fail("Merchant inventory is full")
	var moved := player_inventory.move_slot_to(stock, player_index)
	if not moved:
		return _fail("Could not transfer item")
	if wallet:
		wallet.spend(payment)
	player_wallet.credit(payment)
	trade_completed.emit("SOLD %s  +%d SCRIP" % [stack.definition.display_name.to_upper(), payment])
	return true


func price_for(definition: ItemDefinition, quantity: int, buying: bool) -> int:

	var value := definition.get_component(TradeValueComponent) as TradeValueComponent
	var base: int = value.buy_price if value else max(1, int(ceil(definition.weight * 7.0 + 2.0)))
	if not buying:
		base = value.sell_price if value else max(1, int(floor(base * sell_ratio)))
	elif value == null:
		base = int(ceil(base * buy_markup))
	return max(1, base * quantity)


func _fail(message: String) -> bool:

	trade_failed.emit(message)
	return false
