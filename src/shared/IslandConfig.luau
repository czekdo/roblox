local IslandConfig = {
	IslandSpacing = 850,
	SpawnHeight = 300,
	FallThreshold = -200,
	ExpansionAreaSize = Vector3.new(132, 2, 132),
	ExpansionPadSize = Vector3.new(10, 1, 10),
	ExpansionGap = 28,
	ExpansionResourceNodeCount = 3,
	Expansions = {
		{ Id = "Expansion1", Label = "Expansion 1", Cost = 200, Direction = Vector3.new(0, 0, -1) },
		{ Id = "Expansion2", Label = "Expansion 2", Cost = 500, Direction = Vector3.new(1, 0, -1) },
		{ Id = "Expansion3", Label = "Expansion 3", Cost = 1000, Direction = Vector3.new(1, 0, 0) },
		{ Id = "Expansion4", Label = "Expansion 4", Cost = 2500, Direction = Vector3.new(1, 0, 1) },
		{ Id = "Expansion5", Label = "Expansion 5", Cost = 5000, Direction = Vector3.new(0, 0, 1) },
		{ Id = "Expansion6", Label = "Expansion 6", Cost = 10000, Direction = Vector3.new(-1, 0, 1) },
		{ Id = "Expansion7", Label = "Expansion 7", Cost = 20000, Direction = Vector3.new(-1, 0, 0) },
		{ Id = "Expansion8", Label = "Expansion 8", Cost = 50000, Direction = Vector3.new(-1, 0, -1) },
	},
}

return IslandConfig