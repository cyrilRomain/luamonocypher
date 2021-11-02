
-- quick and dirty test of the major luamonocypher functions

mc = require"luamonocypher"

------------------------------------------------------------------------
-- some local definitions

local strf = string.format
local byte, char = string.byte, string.char
local spack, sunpack = string.pack, string.unpack

local app, concat = table.insert, table.concat

local function stohex(s, ln, sep)
	-- stohex(s [, ln [, sep]])
	-- return the hex encoding of string s
	-- ln: (optional) a newline is inserted after 'ln' bytes 
	--	ie. after 2*ln hex digits. Defaults to no newlines.
	-- sep: (optional) separator between bytes in the encoded string
	--	defaults to nothing (if ln is nil, sep is ignored)
	-- example: 
	--	stohex('abcdef', 4, ":") => '61:62:63:64\n65:66'
	--	stohex('abcdef') => '616263646566'
	--
	if #s == 0 then return "" end
	if not ln then -- no newline, no separator: do it the fast way!
		return (s:gsub('.', 
			function(c) return strf('%02x', byte(c)) end
			))
	end
	sep = sep or "" -- optional separator between each byte
	local t = {}
	for i = 1, #s - 1 do
		t[#t + 1] = strf("%02x%s", s:byte(i),
				(i % ln == 0) and '\n' or sep) 
	end
	-- last byte, without any sep appended
	t[#t + 1] = strf("%02x", s:byte(#s))
	return concat(t)	
end --stohex()

local function hextos(hs, unsafe)
	-- decode an hex encoded string. return the decoded string
	-- if optional parameter unsafe is defined, assume the hex
	-- string is well formed (no checks, no whitespace removal).
	-- Default is to remove white spaces (incl newlines)
	-- and check that the hex string is well formed
	local tonumber = tonumber
	if not unsafe then
		hs = string.gsub(hs, "%s+", "") -- remove whitespaces
		if string.find(hs, '[^0-9A-Za-z]') or #hs % 2 ~= 0 then
			error("invalid hex string")
		end
	end
	return (hs:gsub(	'(%x%x)', 
		function(c) return char(tonumber(c, 16)) end
		))
end -- hextos

local function px(s, msg) 
	print("--", msg or "")
	print(stohex(s, 16, " ")) 
end

------------------------------------------------------------------------
-- Monocypher test

print("------------------------------------------------------------")
print(_VERSION, mc.VERSION )
print("------------------------------------------------------------")


-- xchacha test vector from libsodium-1.0.16
-- see test/aead_xchacha20poly1305.c and aead_xchacha20poly1305.exp

print("testing authenticated encryption...")

k = hextos[[ 
  808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f ]]
n = hextos[[ 07000000404142434445464748494a4b0000000000000000 ]]
m = "Ladies and Gentlemen of the class of '99: If I could offer you "
	.. "only one tip for the future, sunscreen would be it."

e = hextos[[
 45 3c 06 93 a7 40 7f 04 ff 4c 56 ae db 17 a3 c0
 a1 af ff 01 17 49 30 fc 22 28 7c 33 db cf 0a c8
 b8 9a d9 29 53 0a 1b b3 ab 5e 69 f2 4c 7f 60 70
 c8 f8 40 c9 ab b4 f6 9f bf c8 a7 ff 51 26 fa ee
 bb b5 58 05 ee 9c 1c f2 ce 5a 57 26 32 87 ae c5
 78 0f 04 ec 32 4c 35 14 12 2c fc 32 31 fc 1a 8b
 71 8a 62 86 37 30 a2 70 2b b7 63 66 11 6b ed 09
 e0 fd d4 c8 60 b7 07 4b e8 94 fa c9 69 73 99 be
 5c c1
]]

c = mc.encrypt(k,n,m)
-- MAC is prepended to the encrypted text by monocypher
-- and it is appended in the test vectors here
-- so we should have:
assert(c:sub(17) .. c:sub(1, 16) == e)

-- xchacha test vector from 
-- https://github.com/golang/crypto/blob/master/chacha20poly1305/ 
--   chacha20poly1305_vectors_test.go

k = hextos[[ 
	194b1190fa31d483c222ec475d2d6117710dd1ac19a6f1a1e8e894885b7fa631 ]]
n = hextos[[ 6b07ea26bb1f2d92e04207b447f2fd1dd2086b442a7b6852 ]]
m = hextos[[
	f7e11b4d372ed7cb0c0e157f2f9488d8efea0f9bbe089a345f51bdc77e30d139
	2813c5d22ca7e2c7dfc2e2d0da67efb2a559058d4de7a11bd2a2915e
	]]
e = hextos[[
	25ae14585790d71d39a6e88632228a70b1f6a041839dc89a74701c06bfa7c4de
	3288b7772cb2919818d95777ab58fe5480d6e49958f5d2481431014a8f88dab8
	f7e08d2a9aebbe691430011d
	]]
c = mc.encrypt(k, n, m)
assert(c:sub(17) .. c:sub(1, 16) == e)

k = hextos[[ 
	a60e09cd0bea16f26e54b62b2908687aa89722c298e69a3a22cf6cf1c46b7f8a ]]
n = hextos[[ 92da9d67854c53597fc099b68d955be32df2f0d9efe93614 ]]
m = hextos[[
d266927ca40b2261d5a4722f3b4da0dd5bec74e103fab431702309fd0d0f1a259c767b956aa7348ca923d64c04f0a2e898b0670988b15e
	]]
e = hextos[[
9dd6d05832f6b4d7f555a5a83930d6aed5423461d85f363efb6c474b6c4c8261b680dea393e24c2a3c8d1cc9db6df517423085833aa21f9ab5b42445b914f2313bcd205d179430
	]]
c = mc.encrypt(k, n, m)
assert(c:sub(17) .. c:sub(1, 16) == e)

-- decrypt
m2, msg = mc.decrypt(k, n, c)
assert(m2)
assert(m2 == m)


-- test nonce with an arbitrary "increment"
c = mc.encrypt(k, n, m, 123)
m2 = mc.decrypt(k, n, c, 123)
assert(m2 == m)

------------------------------------------------------------------------
print("testing blake2b...")

t = "The quick brown fox jumps over the lazy dog"
e = hextos[[
	A8ADD4BDDDFD93E4877D2746E62817B1
	16364A1FA7BC148D95090BC7333B3673
	F82401CF7AA2E4CB1ECD90296E3F14CB
	5413F8ED77BE73045B13914CDCD6A918  ]]

dig = mc.blake2b(t)
assert(e == dig)

dig16 = mc.blake2b(t, 16)
dig31 = mc.blake2b(t, 31)
assert(#dig16 == 16)
assert(#dig31 == 31)
digk = mc.blake2b(t, 16, k)
assert(digk ~= dig16)
assert(#digk == 16)

------------------------------------------------------------------------
print("testing x25519 key exchange...")

local function keypair()
	local sk = mc.randombytes(32)
	local pk = mc.public_key(sk)
	return pk, sk
end

apk, ask = keypair() -- alice keypair
bpk, bsk = keypair() -- bob keypair

k1 = mc.key_exchange(ask, bpk)
k2 = mc.key_exchange(bsk, apk)
assert(k1 == k2)

------------------------------------------------------------------------
print("testing ed25519 signature...")

local function sign_keypair()
	local sk = mc.randombytes(32)
	local pk = mc.sign_public_key(sk)
	return pk, sk
end

pk, sk = sign_keypair() -- signature keypair

t = "The quick brown fox jumps over the lazy dog"

sig = mc.sign(sk, pk, t)
assert(#sig == 64)
--~ px(sig, 'sig')

-- check signature
assert(mc.check(sig, pk, t))

-- modified text doesn't check
assert(not mc.check(sig, pk, t .. "!"))


------------------------------------------------------------------------
-- key derivation argon2i tests

print("testing argon2i...")

pw = "hello"
salt = "salt salt salt"
k = ""
c0 = os.clock()
k = mc.argon2i(pw, salt, 100000, 10)
assert(#k == 32)
assert(k == hextos[[
  0d ae 6c e3 2c 7f 1b e7 ad a5 58 fb d5 5f 2e bb
  e1 49 b4 6c 29 72 5b 73 e5 34 1f 04 b3 38 bf 08 ]])
  
print("argon2i (100MBytes, 10 iter) Execution time (sec): ", os.clock()-c0)

------------------------------------------------------------------------
print("\ntest_luamonocypher", "ok\n")