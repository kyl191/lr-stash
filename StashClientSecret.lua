--[[
Sta.sh Client Secret
Regretfully, to prevent abuse, I need to obfusicate this
]]
-- client secret is 6ac9aa67308019e9f8a307480dadf5f4
-- Breaking it up isn't intentional, but because the full 32 character string exceeds Lua's max value
-- And breaking it up into 2 16 character strings results in some strange truncation
-- So 4 8 character strings works
client_secret_pt1 = 0x6ac9aa67
client_secret_pt2 = 0x308019e9
client_secret_pt3 = 0xf8a30748
client_secret_pt4 = 0x0dadf5f4

client_id = 114
