local PowerSequences = {}

PowerSequences.Durations = {
    ["Atomic Breath"] = 2.8,
    ["Meteor Rain"] = 3.0,
    ["Singularity"] = 2.4,
    ["Kaiju Stomp"] = 1.5,
    ["Shockwave"] = 1.35,
    ["Comet"] = 1.8,
    ["Demolition Pulse"] = 1.1,
    ["Seismic Line"] = 2.35,
    ["Railgun"] = 2.2,
    ["Gravity Wave"] = 2.0,
    ["Meteor Forge"] = 3.1,
}

PowerSequences.Combos = {
    ["Cataclysm Protocol"] = {"Singularity", "Atomic Breath", "Demolition Pulse"},
    ["Stormbreaker"] = {"Meteor Forge", "Meteor Rain", "Shockwave"},
    ["Void Lance"] = {"Singularity", "Gravity Wave", "Railgun"},
}

function PowerSequences.duration(kind)
    return PowerSequences.Durations[kind] or 1.5
end

function PowerSequences.combo(name)
    return table.clone(PowerSequences.Combos[name] or PowerSequences.Combos["Cataclysm Protocol"])
end

function PowerSequences.comboNames()
    return {"Cataclysm Protocol", "Stormbreaker", "Void Lance"}
end

return PowerSequences
