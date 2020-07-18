extends Node

signal no_enemies_trampling
signal all_enemies_dead
signal enemy_died(points)

var num_enemies_alive = 0
var num_enemies_trampling = 0
var player_alive = false

func enemy_spawned():
	num_enemies_alive += 1
	
func enemy_dead(points=1):
	emit_signal("enemy_died", points)
	if num_enemies_alive > 0:
		num_enemies_alive -= 1
		
	if num_enemies_alive == 0:
		emit_signal("all_enemies_dead")

func begin_trample():
	num_enemies_trampling += 1
	
func end_trample():
	if num_enemies_trampling > 0:
		num_enemies_trampling -= 1
		
	if num_enemies_trampling == 0:
		emit_signal("no_enemies_trampling")
