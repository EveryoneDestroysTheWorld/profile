--!strict
-- This module is a class that represents a player profile.
--
-- Programmers: Christian Toney (Christian_Toney)
-- © 2024 – 2025 Beastslash LLC

local DataStoreService = game:GetService("DataStoreService");
local DataStore = {
  PlayerMetadata = DataStoreService:GetDataStore("PlayerMetadata");
  Inventory = DataStoreService:GetDataStore("Inventory");
}
local HttpService = game:GetService("HttpService");

type ProfileProperties = {
  
  -- The player's ID.
  id: number;

  timeFirstPlayed: number;

  timeLastPlayed: number;
  
}

local Profile = {
  __index = {} :: ProfileMethods;
};

export type ProfileMethods = {
  delete: (self: Profile) -> ();
  getArchetypeIDs: (self: Profile) -> {string};
  updateArchetypeIDs: (self: Profile, newArchetypeIDList: {string}) -> ();
  getStages: (self: Profile) -> ();
}

export type Profile = typeof(setmetatable({}, {__index = Profile.__index})) & ProfileProperties & ProfileMethods;

-- Returns a new Player object.
function Profile.new(properties: ProfileProperties): Profile
  
  local player = {
    id = properties.id;
    timeFirstPlayed = properties.timeFirstPlayed;
    timeLastPlayed = properties.timeLastPlayed;
  };
  setmetatable(player, {__index = Profile.__index});

  return player :: any;
  
end

-- Returns a Player object based on the ID.
function Profile.fromID(playerID: number, createIfNotFound: boolean?): Profile
  
  local playerData = DataStore.PlayerMetadata:GetAsync(playerID);
  if not playerData and createIfNotFound then

    local playTime = DateTime.now().UnixTimestampMillis;
    playerData = HttpService:JSONEncode({
      id = playerID;
      timeFirstPlayed = playTime;
      timeLastPlayed = playTime;
    });
    DataStore.PlayerMetadata:SetAsync(playerID, playerData, {playerID});

  end;
  assert(playerData, `Player {playerID} not found.`);
  
  return Profile.new(HttpService:JSONDecode(playerData));
  
end

-- Deletes all player data.
function Profile.__index:delete(): ()

end;

-- Returns a list of archetype IDs.
function Profile.__index:getArchetypeIDs(): {string}

  local archetypeIDs = {};
  local keyList = DataStore.Inventory:ListKeysAsync(`{self.id}/archetypes`);
  repeat

    local keys = keyList:GetCurrentPage();
    for _, key in ipairs(keys) do

      local archetypeIDListEncoded = DataStore.Inventory:GetAsync(key.KeyName);
      if archetypeIDListEncoded then

        local archetypeIDList = HttpService:JSONDecode(archetypeIDListEncoded);
        for _, archetypeID in ipairs(archetypeIDList) do

          table.insert(archetypeIDs, archetypeID);
          
        end;

      else

        DataStore.Inventory:RemoveAsync(key.KeyName);

      end;
  
    end;

    if not keyList.IsFinished then

      keyList:AdvanceToNextPageAsync();

    end;

  until keyList.IsFinished;

  return archetypeIDs;

end;

-- Updates the player's owned archetype ID list.
function Profile.__index:updateArchetypeIDs(newArchetypeList: {string}): ()

  -- Divide the IDs into separate lists to comply with Roblox's datastore limitations.
  local pages: {{string}} = {};
  local currentPage = 1;
  pages[currentPage] = newArchetypeList;
  while pages[currentPage] do

    while HttpService:JSONEncode(pages[currentPage]):len() >= 4194304 do

      if not pages[currentPage + 1] then
        
        pages[currentPage + 1] = {};

      end;

      table.insert(pages[currentPage + 1], pages[currentPage][#pages[currentPage]])
      table.remove(pages[currentPage], #pages[currentPage]);

    end;

    currentPage += 1;

  end;

  for pageNumber, page in ipairs(pages) do

    DataStore.Inventory:SetAsync(`{self.id}/archetypes/{pageNumber}`, HttpService:JSONEncode(page));

  end;

  -- Removed unused pages from the datastore.
  local keyList = DataStore.Inventory:ListKeysAsync(`{self.id}/archetypes`);
  repeat

    local keys = keyList:GetCurrentPage();
    for _, key in ipairs(keys) do

      local pageNumberStringIndex = key.KeyName:match("^.*()/");
      local pageNumber = tonumber(key.KeyName:sub(pageNumberStringIndex + 1));
      if pageNumber and pageNumber > #pages then

        DataStore.Inventory:RemoveAsync(key.KeyName);

      end;

  
    end;

    if not keyList.IsFinished then

      keyList:AdvanceToNextPageAsync();

    end;

  until keyList.IsFinished;

end;

return Profile;