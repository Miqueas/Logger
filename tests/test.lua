local logit  = require("../logit")
local logger = logit:new("./", "Test", nil, true)

logger(2, "Log library started!")
logger(3, "This is a debug message")

logger:expect(true)
logger:expect(false, "E", "E")
