class "kAdminServer"

function kAdminServer:__init()
	self.m_ChatEvent = Events:Subscribe("Player:Chat", self, self.OnChat)
	self.m_UpdateEvent = Events:Subscribe("Engine:Update", self, self.OnUpdate)
	
	self.m_Commands = {
		["!voteban"] = self.OnVoteBan,
		["!votekick"] = self.OnVoteKick,
		["!y"] = self.OnYes,
		["!n"] = self.OnNo,
		["!yes"] = self.OnYes,
		["!no"] = self.OnNo,
		["!cancel"] = self.OnCancel
	}
	
	-- Maximum time for a vote (in seconds)
	self.m_MaxTime = 30.0

	-- Current count-up timer
	self.m_CurrentTime = 0.0

	-- Is there currently a vote in session
	self.m_IsVoteCalled = false
	
	-- Is the vote to kick or ban someone
	self.m_VoteType = "none" -- "kick" "ban"

	-- Player who called the vote (id, use player manager to get reference)
	self.m_CalledByPlayerId = nil

	-- Player who the vote is attempting to kick/ban (id, use player manager to get reference)
	self.m_PlayerCalledOnId = nil
	
	-- Players who voted yes
	self.m_PlayersYes = {}

	-- Forget about the players who don't vote
end

function kAdminServer:OnChat(p_Player, p_Mask, p_Message)
	--print("[kBot] " .. p_Player.name .. ": " .. p_Message)
	if p_Player == nil then
		return
	end
	
	local s_Commands = split(p_Message, " ")
	
	local s_Command = s_Commands[1]
	if s_Command == nil then
		return
	end
	
	s_Function = self.m_Commands[s_Command]
	if s_Function == nil then
		return
	end
	
	s_Function(self, p_Player, p_Mask, p_Message, s_Commands)
end

function kAdminServer:OnUpdate(p_Delta, p_SimulationDelta)
	-- If there is not a vote being called do not update anything (saves perf)
	if self.m_IsVoteCalled == false then
		self.m_CurrentTime = 0.0
		return
	end
	
	-- Check to see if we reached our max time
	if self.m_CurrentTime >= self.m_MaxTime then
		-- Call the final results handler
		self:OnFinalResults()
		
		-- Disable that anyone called a vote
		self.m_IsVoteCalled = false

		-- Reset the timer
		self.m_CurrentTime = 0.0
		
		ChatManager:SendMessage("[kAdmin] Vote Expired")
		print("Vote Expired")
		return
	end
	
	-- Increment our delta
	self.m_CurrentTime = self.m_CurrentTime + p_Delta
end

function kAdminServer:OnFinalResults()
	s_YesCount = 0
	for _, ignored in pairs(self.m_PlayersYes) do
		s_YesCount = s_YesCount + 1
	end

	local s_PlayerCount = PlayerManager:GetPlayerCount()
	
	-- If our player count is zero, how in the heck did this get called?
	if s_PlayerCount == 0 then
		return
	end
	
	local s_Percentage = s_YesCount / s_PlayerCount
	if s_Percentage >= 0.5 then
		print("[kAdmin] Vote passed.")

		-- Get the player from the player manager
		s_PlayerCalledOn = PlayerManager:GetPlayerById(self.m_PlayerCalledOnId)
		if s_PlayerCalledOn ~= nil then
			if self.m_VoteType == "kick" then
				print("[kAdmin] Player " .. s_PlayerCalledOn.name .. " has been kicked from the server!")
				ChatManager:SendMessage("[kAdmin] Player " .. s_PlayerCalledOn.name .. " has been kicked from the server!")
				s_PlayerCalledOn:Kick()
			end
			
			if self.m_VoteType == "ban" then
				print("[kAdmin] Player " .. s_PlayerCalledOn.name .. " has been BANNED from the server!")
				ChatManager:SendMessage("[kAdmin] Player " .. s_PlayerCalledOn.name .. " has been BANNED from the server!")
				s_PlayerCalledOn:Ban()
			end
		end
	else
		print("[kAdmin] Vote failed, not enough votes (" .. s_YesCount .. "/" .. s_PlayerCount .. ")")
		ChatManager:SendMessage("[kAdmin] Vote failed, not enough votes (" .. s_YesCount .. "/" .. s_PlayerCount .. ")")
	end
	
	self.m_CalledByPlayerId = nil
	self.m_PlayerCalledOnId = nil
	self.m_IsVoteCalled = false
	self.m_VoteType = "none"
	self.m_PlayersYes = {}
	print("[kAdmin] Vote reset.")
end

-- !voteban <partial player name>
function kAdminServer:OnVoteBan(p_Player, p_Mask, p_Message, p_Commands)
	print("OnVoteBan called")
	
	-- If a vote is already in progress don't do anything
	if self.m_IsVoteCalled == true then
		return
	end
	
	-- Set that there is a vote in progress
	self.m_IsVoteCalled = true

	s_CommandLength = 0
	for _, ignored in pairs(p_Commands) do
		s_CommandLength = s_CommandLength + 1
	end

	if s_CommandLength < 2 then
		return
	end
	
	local s_PlayerSearchString = p_Commands[2]
	print("PlayerSearch:" .. s_PlayerSearchString)
	
	local s_Players = PlayerManager:GetPlayers()
	for s_Index, s_Player in pairs(s_Players) do
		print("Searching:" .. s_Player.name)
		
		if string.match(s_Player.name, s_PlayerSearchString) then
			self.m_CalledByPlayerId = p_Player.id
			self.m_PlayerCalledOnId = s_Player.id
			break
		end
	end
	
	-- Validate that we have a correct id
	if self.m_PlayerCalledOnId == nil then
		self.m_IsVoteCalled = false
		print("PlayerCalledOn is invalid.")
		return
	end
	
	-- Validate that the player that called it still exists
	if self.m_CalledByPlayerId == nil then
		self.m_IsVoteCalled = false
		print("CalledByPlayer is invalid.")
		return
	end
	
	if self.m_PlayerCalledOnId == self.m_CalledByPlayerId then
		print("Dumbass " .. self.m_PlayerCalledOnId .. " tried to call a vote on him/her/itself.")
		self.m_CalledByPlayerId = nil
		self.m_PlayerCalledOnId = nil
		self.m_IsVoteCalled = false
		return
	end
	
	self.m_VoteType = "ban"
	
	self:EchoVote()
end

function kAdminServer:OnVoteKick(p_Player, p_Mask, p_Message, p_Commands)
	print("OnVoteKick called")
	
	-- If a vote is already in progress don't do anything
	if self.m_IsVoteCalled == true then
		return
	end
	
	-- Set that there is a vote in progress
	self.m_IsVoteCalled = true
	
	local s_PlayerSearchString = p_Commands[2]
	print("PlayerSearch:" .. s_PlayerSearchString)
	
	local s_Players = PlayerManager:GetPlayers()
	for s_Index, s_Player in pairs(s_Players) do
		print("Searching:" .. s_Player.name)
		
		if string.match(string.lower(s_Player.name), string.lower(s_PlayerSearchString)) then
			self.m_CalledByPlayerId = p_Player.id
			self.m_PlayerCalledOnId = s_Player.id
			break
		end
	end
	
	if self.m_PlayerCalledOnId == nil then
		self.m_IsVoteCalled = false
		print("PlayerCalledOn is invalid.")
		return
	end
	
	if self.m_CalledByPlayerId == nil then
		self.m_IsVoteCalled = false
		print("CalledByPlayer is invalid.")
		return
	end
	
	if self.m_PlayerCalledOnId == self.m_CalledByPlayerId then
		print("Dumbass " .. self.m_PlayerCalledOnId .. " tried to call a vote on him/her/itself.")
		self.m_CalledByPlayerId = nil
		self.m_PlayerCalledOnId = nil
		self.m_IsVoteCalled = false
		return
	end
	
	self.m_VoteType = "kick"
	

	self:OnYes(PlayerManager:GetPlayerById(self.m_CalledByPlayerId), 0, "", {"", ""})
	self:EchoVote()
end

function kAdminServer:EchoVote()
	if self.m_CalledByPlayerId == nil then
		return
	end
	
	if self.m_PlayerCalledOnId == nil then
		return
	end

	s_CalledByPlayer = PlayerManager:GetPlayerById(self.m_CalledByPlayerId)
	if s_CalledByPlayer == nil then
		return
	end

	s_PlayerCalledOn = PlayerManager:GetPlayerById(self.m_PlayerCalledOnId)
	if s_PlayerCalledOn == nil then
		return
	end
	
	print("[kAdmin] Player " .. s_CalledByPlayer.name .. " called a vote to kick on " .. s_PlayerCalledOn.name)
	ChatManager:SendMessage("[kAdmin] Vote to " .. self.m_VoteType .. " " .. s_PlayerCalledOn.name .. " has started! Vote Yes with !y or !yes and No with !n or !no or cancel with !cancel.")
end

function kAdminServer:OnYes(p_Player, p_Mask, p_Message, p_Commands)
	-- Don't allow a player to vote more than once
	for playerIndex, playerId in ipairs(self.m_PlayersYes) do
		if playerId == p_Player.id then
			return
		end
	end
	
	table.insert(self.m_PlayersYes, p_Player.id)
end

function kAdminServer:OnNo(p_Player, p_Mask, p_Message, p_Commands)	
	-- If players want to switch their vote remove them from the Yes Vote
	for i, v in ipairs(self.m_PlayersYes) do
		if v == p_Player.id then
			self.m_PlayersYes:remove(i)
			return
		end
	end
end

function kAdminServer:OnCancel(p_Player, p_Mask, p_Message, p_Commands)
	if p_Player == nil then
		return
	end
	
	if self.m_CalledByPlayerId == nil then
		return
	end
	
	if self.m_IsVoteCalled == false then
		return
	end
	
	if self.m_CalledByPlayerId == p_Player.id then
		self.m_CalledByPlayerId = nil
		self.m_PlayerCalledOnId = nil
		self.m_IsVoteCalled = false
		self.m_VoteType = "none"
		ChatManager:SendMessage("[kAdmin] Vote cancelled!")
	end
end
-- Copy pasta'd from http://www.computercraft.info/forums2/index.php?/topic/930-lua-string-split/page__p__93664#entry93664
function split(pString, pPattern)
   local Table = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pPattern
   local last_end = 1
   local s, e, cap = pString:find(fpat, 1)
   while s do
	  if s ~= 1 or cap ~= "" then
	 table.insert(Table,cap)
	  end
	  last_end = e+1
	  s, e, cap = pString:find(fpat, last_end)
   end
   if last_end <= #pString then
	  cap = pString:sub(last_end)
	  table.insert(Table, cap)
   end
   return Table
end

local g_AdminServer = kAdminServer()
