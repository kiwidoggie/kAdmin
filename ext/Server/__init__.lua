class "kAdminServer"


local function string_StartWith( String, Start )
   return string.sub( String, 1, string.len (Start ) ) == Start
end

function kAdminServer:__init()
	self.m_ChatEvent = Events:Subscribe("Player:Chat", self, self.OnChat)
	self.m_UpdateEvent = Events:Subscribe("Engine:Update", self, self.OnUpdate)
	
	self.m_Commands = {
		["voteban"] = self.OnVoteBan,
		["votekick"] = self.OnVoteKick,
		["yes"] = self.OnYes,
		["no"] = self.OnNo,
		["cancel"] = self.OnCancel
	}
	
	self.m_MaxTime = 30.0 -- max call a vote for for 30s
	self.m_CurrentTime = 0.0
	self.m_IsVoteCalled = false
	
	self.m_VoteType = "none" -- "kick" "ban"
	self.m_CalledByPlayer = nil
	self.m_PlayerCalledOn = nil
	
	self.m_PlayersYes = {}
	self.m_PlayersNo = {}
	-- Forget about the players who don't vote
end

function kAdminServer:OnChat(p_Player, p_Mask, p_Message)
	--print("[kBot] " .. p_Player.name .. ": " .. p_Message)
	if p_Player == nil then
		return
	end
	if string.len(p_Message) < 2 and p_Message[1] ~= "!"  then return end -- less than 2 char and not ! at the start
	p_Message = string.sub(p_Message, 2, string.len(p_Message)) -- remove the "!"  (and then remove kebab)
	if string.find(p_Message, " ") then -- cut space and after
		p_Message = string.sub(p_Message, 1, select(1, string.find(p_Message, " "))-1) -- find space and remove after
	end

	local found = 0;
	local foundstr;
	for k, v in pairs(self.m_Commands) do
		if string_StartWith(v, p_Message) then
			found = found + 1
			foundfunc = self.m_Commands[found];
		end
	end
	if found ~= 1 then return end -- if found < 1 , found nothing, if > 1, we got two commands with the same start
	foundfunc(self, p_Player, p_Mask, p_Message, s_Commands)
end

function kAdminServer:OnUpdate(p_Delta, p_SimulationDelta)
	if self.m_IsVoteCalled == false then
		self.m_CurrentTime = 0.0
		return
	end
	
	-- Check to see if we reached our max time
	if self.m_CurrentTime >= self.m_MaxTime then
		
		self:OnFinalResults()
		
		self.m_IsVoteCalled = false
		self.m_CurrentTime = 0.0
		
		ServerChatManager:SendMessage("[kAdmin] Vote Expired")
		print("Vote Expired")
		return
	end
	
	-- Increment our delta
	self.m_CurrentTime = self.m_CurrentTime + p_Delta
	
	
end

function kAdminServer:OnFinalResults()
	local s_YesCount = table.getn(self.m_PlayersYes)
	local s_NoCount = table.getn(self.m_PlayersNo)
	local s_PlayerCount = PlayerManager:GetPlayerCount()
	
	-- If our player count is zero, how in the heck did this get called?
	if s_PlayerCount == 0 then
		return
	end
	
	local s_Percentage = s_YesCount / s_PlayerCount
	if s_Percentage >= 0.5 then
		print("[kAdmin] Vote passed.")
		if self.m_VoteType == "kick" then
			self.m_PlayerCalledOn:kick()
		end
		
		if self.m_VoteType == "ban" then
			self.m_PlayerCalledOn:ban()
		end
		
		ServerChatManager:SendMessage("[kAdmin] Vote Passed!")
	else
		print("[kAdmin] Vote failed.")
		ServerChatManager:SendMessage("[kAdmin] Vote Failed!")
	end
	
	self.m_CalledByPlayer = nil
	self.m_PlayerCalledOn = nil
	self.m_IsVoteCalled = false
	self.m_VoteType = "none"
	self.m_PlayersYes = {}
	self.m_PlayersNo = {}
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
	
	if table.getn(p_Commands) < 2 then
		return
	end
	
	local s_PlayerSearchString = p_Commands[2]
	print("PlayerSearch:" .. s_PlayerSearchString)
	
	local s_Players = PlayerManager:GetPlayers()
	for s_Index, s_Player in pairs(s_Players) do
		print("Searching:" .. s_Player.name)
		
		if string.match(s_Player.name, s_PlayerSearchString) then
			self.m_CalledByPlayer = p_Player
			self.m_PlayerCalledOn = s_Player
			break
		end
	end
	
	if self.m_PlayerCalledOn == nil then
		self.m_IsVoteCalled = false
		print("PlayerCalledOn is invalid.")
		return
	end
	
	if self.m_CalledByPlayer == nil then
		self.m_IsVoteCalled = false
		print("CalledByPlayer is invalid.")
		return
	end
	
	if self.m_PlayerCalledOn.name == self.m_CalledByPlayer.name then
		print("Dumbass " .. self.m_PlayerCalledOn.name .. " tried to call a vote on him/her/itself.")
		self.m_CalledByPlayer = nil
		self.m_PlayerCalledOn = nil
		self.m_IsVoteCalled = false
		-- TODO: Send message back to player saying they are a dumbass
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
			self.m_CalledByPlayer = p_Player
			self.m_PlayerCalledOn = s_Player
			break
		end
	end
	
	if self.m_PlayerCalledOn == nil then
		self.m_IsVoteCalled = false
		print("PlayerCalledOn is invalid.")
		return
	end
	
	if self.m_CalledByPlayer == nil then
		self.m_IsVoteCalled = false
		print("CalledByPlayer is invalid.")
		return
	end
	
	if self.m_PlayerCalledOn.name == self.m_CalledByPlayer.name then
		print("Dumbass " .. self.m_PlayerCalledOn.name .. " tried to call a vote on him/her/itself.")
		self.m_CalledByPlayer = nil
		self.m_PlayerCalledOn = nil
		self.m_IsVoteCalled = false
		return
	end
	
	self.m_VoteType = "kick"
	
	self:EchoVote()
end

function kAdminServer:EchoVote()
	if self.m_CalledByPlayer == nil then
		return
	end
	
	if self.m_PlayerCalledOn == nil then
		return
	end
	
	print("[kAdmin] Player " .. self.m_CalledByPlayer.name .. " called a vote to kick on " .. self.m_PlayerCalledOn.name)
	ServerChatManager:SendMessage("[kAdmin] Vote to " .. self.m_VoteType .. " " .. self.m_PlayerCalledOn.name .. " has started! Vote Yes with !y or !yes and No with !n or !no or cancel with !cancel.")
end

function kAdminServer:OnYes(p_Player, p_Mask, p_Message, p_Commands)
	local s_PlayerName = p_Player.name
	
	-- Don't allow a player to vote more than once
	for i, v in ipairs(self.m_PlayersYes) do
		if string.match(v.name, s_PlayerName) then
			return
		end
	end
	
	-- If players want to switch their vote remove them from the Yes Vote
	for i, v in ipairs(self.m_PlayersNo) do
		if string:match(v.name, s_PlayerName) then
			self.m_PlayersNo:remove(i)
			break
		end
	end
	
	table.insert(self.m_PlayersYes, p_Player)
end

function kAdminServer:OnNo(p_Player, p_Mask, p_Message, p_Commands)
	local s_PlayerName = p_Player.name
	
	-- Don't allow a player to vote more than once
	for i, v in ipairs(self.m_PlayersNo) do
		if string.match(v.name, s_PlayerName) then
			return
		end
	end
	
	-- If players want to switch their vote remove them from the Yes Vote
	for i, v in ipairs(self.m_PlayersYes) do
		if string.match(v.name, s_PlayerName) then
			self.m_PlayersYes:remove(i)
			break
		end
	end
	
	table.insert(self.m_PlayersNo, p_Player)
end

function kAdminServer:OnCancel(p_Player, p_Mask, p_Message, p_Commands)
	if p_Player == nil then
		return
	end
	
	if self.m_CalledByPlayer == nil then
		return
	end
	
	if self.m_IsVoteCalled == false then
		return
	end
	
	if string.match(p_Player.name, self.m_CalledByPlayer.name) then
		self.m_CalledByPlayer = nil
		self.m_PlayerCalledOn = nil
		self.m_IsVoteCalled = false
		self.m_VoteType = "none"
		ServerChatManager:SendMessage("[kAdmin] Vote cancelled!")
	end
end
