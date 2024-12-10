-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- CompilerB.lua
-- This Script contains the new CompilerB

-- The max Number of variables used as registers
local MAX_REGS = 100;
local MAX_REGS_MUL = 0;


local DUMMY_BLOCK_PROBABILITY = 0.2;
local OPAQUE_PREDICATE_PROBABILITY = 0.3;        -- 30% of the time
local MAX_REGISTERS = 5                          -- 5 registers
local RARELY_CHECKED_CONDITION_PROBABILITY = 0.1 -- 10% of the time
local cflowFlatteningProbability = 0.3           -- 30% of the time

local CompilerB = {}
CompilerB.Name = "Compiler B"

local Ast = require("Prometheus.ast");
local Scope = require("Prometheus.scope");
local logger = require("logger");
local util = require("Prometheus.util");
local visitast = require("Prometheus.visitast")
local randomStrings = require("Prometheus.randomStrings")
local ControlFlowObfuscator = require("Prometheus.ControlFlowGen")

local lookupify = util.lookupify;
local AstKind = Ast.AstKind;

local unpack = unpack or table.unpack;
local math_random = math.random

-- Moved BIN_OPS outside of the function
local BIN_OPS = lookupify {
    AstKind.LessThanExpression,
    AstKind.GreaterThanExpression,
    AstKind.LessThanOrEqualsExpression,
    AstKind.GreaterThanOrEqualsExpression,
    AstKind.NotEqualsExpression,
    AstKind.EqualsExpression,
    AstKind.StrCatExpression,
    AstKind.AddExpression,
    AstKind.SubExpression,
    AstKind.MulExpression,
    AstKind.DivExpression,
    AstKind.ModExpression,
    AstKind.PowExpression,
    AstKind.OrExpression,
    AstKind.AndExpression,
    AstKind.StrCatExpression,
    AstKind.BAndExpression
}

local function createUniqueTable()
    return setmetatable({}, {})
end

function CompilerB:new(maxRegs)
    maxRegs = maxRegs or MAX_REGS -- Use the provided value or the default
    self.BIN_OPS = BIN_OPS
    local CompilerB = {
        blocks = {},
        registers = {},
        activeBlock = nil,
        registersForVar = {},
        usedRegisters = 0,
        maxUsedRegister = 0,
        registerVars = {},
        maxRegs = maxRegs,

        VAR_REGISTER = createUniqueTable(),
        RETURN_ALL = createUniqueTable(),
        POS_REGISTER = createUniqueTable(),
        RETURN_REGISTER = createUniqueTable(),
        UPVALUE = createUniqueTable()
    };

    setmetatable(CompilerB, self);
    self.__index = self;

    return CompilerB;
end

-- Custom table.find implementation
local function table_find(t, value)
    for i, v in ipairs(t) do
        if v == value then
            return i
        end
    end
    return nil
end

-- Add this function to adjust the number of registers
function CompilerB:adjustRegisters(complexity)
    self.maxRegs = complexity -- Adjust the number of registers based on the complexity
end

-- Enhanced substituteInstruction with dynamic complexity adjustment and polymorphic techniques
function CompilerB:substituteInstruction(op, a, b, complexityFactor)
    local complexityAdjustment = complexityFactor or 1
    local complexSubstitutions = {
        add = function(a, b)
            local patterns = {
                function(a, b) return string.format("((%s ^ %s) ^ (%s & %s)) * %d", a, b, a, b, complexityAdjustment) end,
                function(a, b)
                    return string.format("(%s + %s + %d) - %d", a, b, complexityAdjustment,
                        complexityAdjustment)
                end
            }
            return patterns[math_random(#patterns)](a, b)
        end,
        sub = function(a, b)
            local patterns = {
                function(a, b) return string.format("((%s + ~%s + 1) - %d)", a, b, complexityAdjustment) end,
                function(a, b) return string.format("(%s - (%s + %d))", a, b, complexityAdjustment) end
            }
            return patterns[math_random(#patterns)](a, b)
        end,
        mul = function(a, b)
            local patterns = {
                function(a, b) return string.format("(((%s >> 1) * %s) << 1) / %d", a, b, complexityAdjustment) end,
                function(a, b) return string.format("(%s * %s) / %d", a, b, complexityAdjustment) end
            }
            return patterns[math_random(#patterns)](a, b)
        end,
        div = function(a, b)
            local patterns = {
                function(a, b) return string.format("(math.floor(%s * (1 / %s)) + %d)", a, b, complexityAdjustment) end,
                function(a, b) return string.format("((%s / %s) + %d)", a, b, complexityAdjustment) end
            }
            return patterns[math_random(#patterns)](a, b)
        end,
    }
    local choices = complexSubstitutions[op]
    if not choices then
        return op
    end
    return choices(a, b)
end

-- Enhanced generateDeadCodePath with dynamic complexity and metamorphic techniques
function CompilerB:generateDeadCodePath(dynamicData)
    local ops = { "add", "sub", "mul", "div", "nop", "xor", "or", "and", "mod", "pow", "concat", "eq", "lt", "le", "gt",
        "ge", "ne" }
    local complexityFactor = dynamicData and #tostring(dynamicData) % 10 or 1
    local generateComplexOperation = function(complexityFactor)
        local opIndex = math_random(#ops)
        local op = ops[opIndex]
        local val1, val2 = "a" .. math_random(1, 100), "b" .. math_random(1, 100)
        local substitutedOp = self:substituteInstruction(op, val1, val2, complexityFactor)
        return substitutedOp
    end
    local deadCode = {}
    for i = 1, math_random(3, 7) do
        table.insert(deadCode, generateComplexOperation(complexityFactor))
    end
    -- Metamorphic transformation: shuffle the dead code lines to change their order
    local shuffledDeadCode = {}
    while #deadCode > 0 do
        table.insert(shuffledDeadCode, table.remove(deadCode, math_random(#deadCode)))
    end
    return table.concat(shuffledDeadCode, "\n")
end

-- Enhanced reorderStatements with dynamic complexity adjustment and polymorphic techniques
function CompilerB:reorderStatements(statements, complexityFactor)
    local graph = {}
    for i, statement in ipairs(statements) do
        graph[i] = {}
        for j, otherStatement in ipairs(statements) do
            if i ~= j then
                local writes = statement.writes or {}
                local reads = otherStatement.reads or {}
                for var in pairs(writes) do
                    if reads[var] then
                        graph[i][j] = true
                        break
                    end
                end
            end
        end
    end

    local reordered = {}
    while #reordered < #statements do
        for i, deps in pairs(graph) do
            if not next(deps) and not table_find(reordered, i) then
                table.insert(reordered, i)
                for _, otherDeps in pairs(graph) do
                    otherDeps[i] = nil
                end
                break
            end
        end
    end

    local reorderedStatements = {}
    for _, index in ipairs(reordered) do
        table.insert(reorderedStatements, statements[index])
    end
    if complexityFactor and complexityFactor > 1 then
        if complexityFactor % 2 == 1 then
            reorderedStatements = util.reverse(reorderedStatements)
        else
            -- Polymorphic adjustment: shuffle the statements if complexityFactor is even
            local shuffledStatements = {}
            while #reorderedStatements > 0 do
                table.insert(shuffledStatements, table.remove(reorderedStatements, math_random(#reorderedStatements)))
            end
            reorderedStatements = shuffledStatements
        end
    end
    return reorderedStatements
end

-- Control Flow Flattening/Obfuscation (Cflow)
-- Enhanced createBlock with dynamic complexity adjustment, polymorphic and metamorphic techniques
function CompilerB:createBlock(parentBlock, condition, dynamicData, nestingLevel)
    local obfuscator = ControlFlowObfuscator:new()
    self.idCounter = (self.idCounter or 0) + 1
    local id = self.idCounter
    local scope = Scope:new(self.containerFuncScope)

    local complexity = math_random(5, 15)
    if dynamicData then
        complexity = complexity + #tostring(dynamicData) % 5
    end
    local obfuscatedCondition = obfuscator:generateNestedObfuscatedConditionWithRarelyCheckedConditions(complexity)

    local block = {
        id = id,
        statements = {},
        subBlocks = {},
        scope = scope,
        advanceToNextBlock = true,
        condition = obfuscatedCondition,
    }

    self.blocks[#self.blocks + 1] = block

    if parentBlock then
        parentBlock.subBlocks[#parentBlock.subBlocks + 1] = block
    end

    local complexityFactor = dynamicData and #tostring(dynamicData) % 10 or 1
    for i = 1, math_random(2, 3) * complexityFactor do -- Use complexityFactor to adjust the number of iterations
        if math_random() < DUMMY_BLOCK_PROBABILITY then
            local dummyComplexity = math_random(5, 15)
            if dynamicData then
                dummyComplexity = dummyComplexity + #tostring(dynamicData) % 5
            end
            local obfuscatedDummyCondition = obfuscator:generateNestedObfuscatedConditionWithRarelyCheckedConditions(
                dummyComplexity)

            local dummyBlock = {
                id = self.idCounter + 1,
                statements = {},
                subBlocks = {},
                scope = scope,
                advanceToNextBlock = false,
                condition = obfuscatedDummyCondition,
            }
            self.blocks[#self.blocks + 1] = dummyBlock
            self.idCounter = self.idCounter + 1
        end
    end

    -- Enhanced control flow structures
    local controlFlowStructures = { "if", "while", "for", "switch", "repeat-until" }
    local selectedStructure = controlFlowStructures[math_random(#controlFlowStructures)]

    -- Handling for new control flow structures
    if selectedStructure == "while" or selectedStructure == "for" or selectedStructure == "repeat-until" then
        local loopCondition = obfuscator:generateNestedObfuscatedConditionWithRarelyCheckedConditions(complexity)
        local loopBlock = {
            op = selectedStructure,
            condition = loopCondition,
            body = {},
        }
        for j = 1, math_random(2, 4) * complexityFactor do -- Adjusted for complexityFactor
            local inliningCondition = obfuscator:inlining()
            local eqmutateCondition = obfuscator:eqmutate()
            local bounceCondition = obfuscator:bounce()
            local mutatedNumber = obfuscator:numberMutation()
            table.insert(loopBlock.body, {
                op = "if",
                condition = condition,
                thenBlock = mutatedNumber,
                elseBlock = (mutatedNumber + 1) % #self.registers,
                inliningCondition = inliningCondition,
                eqmutateCondition = eqmutateCondition,
                bounceCondition = bounceCondition
            })
        end
        table.insert(block.statements, loopBlock)
    elseif selectedStructure == "switch" then
        local switchBlock = {
            op = "switch",
            condition = obfuscator:numberMutation(),
            cases = {},
        }
        for k = 1, math_random(2, 4) * complexityFactor do -- Adjusted for complexityFactor
            local caseCondition = obfuscator:generateNestedObfuscatedConditionWithRarelyCheckedConditions(complexity)
            table.insert(switchBlock.cases, {
                case = k,
                condition = caseCondition,
                body = obfuscator:generateNestedObfuscatedConditionWithRarelyCheckedConditions(complexity + k),
            })
        end
        table.insert(block.statements, switchBlock)
    end

    -- Recursively create sub-blocks for increased nesting
    if nestingLevel and nestingLevel > 0 then
        for i = 1, math_random(1, 3) * complexityFactor do -- Adjusted for complexityFactor
            self:createBlock(block, condition, dynamicData, nestingLevel - 1)
        end
    end

    block.statements = self:shuffle(block.statements)

    local switchCase = {}
    for i, subBlock in ipairs(block.subBlocks) do
        switchCase[i] = subBlock
    end
    block.switchCase = switchCase

    block.selectBlock = function(self, input)
        local index = (input + 1) % #self.switchCase
        return self.switchCase[index]
    end

    if math_random() < cflowFlatteningProbability and #self.registers > 0 then
        local condition = obfuscator:generateNestedObfuscatedConditionWithRarelyCheckedConditions(obfuscator
            :numberMutation())
        for i = 1, math_random(2, 4) * complexityFactor do -- Adjusted for complexityFactor
            if math_random() < OPAQUE_PREDICATE_PROBABILITY then
                local inliningCondition = obfuscator:inlining()
                local eqmutateCondition = obfuscator:eqmutate()
                local bounceCondition = obfuscator:bounce()
                local mutatedNumber = obfuscator:numberMutation()
                table.insert(block.statements, {
                    op = "if",
                    condition = condition,
                    thenBlock = mutatedNumber,
                    elseBlock = (mutatedNumber + 1) % #self.registers,
                    inliningCondition = inliningCondition,
                    eqmutateCondition = eqmutateCondition,
                    bounceCondition = bounceCondition
                })
            end
        end

        block.statements = self:shuffle(block.statements)
    end

    return block;
end

-- Function to shuffle an array using the Fisher-Yates shuffle algorithm
function CompilerB:shuffle(array)
    local n = #array
    for i = n, 2, -1 do
        -- Pick a random index from 1 to i
        local j = math_random(i)

        -- Swap array[i] with array[j]
        array[i], array[j] = array[j], array[i]
    end

    return array
end

function CompilerB:setActiveBlock(block)
    self.activeBlock = block;
end

function CompilerB:addStatement(statement, writes, reads, usesUpvals)
    -- Check if writes or reads is nil before calling lookupify
    local writesLookup, readsLookup
    if writes then
        writesLookup = lookupify(writes)
    else
        writesLookup = {}
    end

    if reads then
        readsLookup = lookupify(reads)
    else
        readsLookup = {}
    end

    if self.activeBlock.advanceToNextBlock then
        table.insert(self.activeBlock.statements, {
            statement = statement,
            writes = writesLookup,
            reads = readsLookup,
            usesUpvals = usesUpvals or false,
        })
    end
end

function CompilerB:compile(ast)
    self.blocks               = {};
    self.registers            = {};
    self.activeBlock          = nil;
    self.registersForVar      = {};
    self.scopeFunctionDepths  = {};
    self.maxUsedRegister      = 0;
    self.usedRegisters        = 0;
    self.registerVars         = {};
    self.usedBlockIds         = {};

    self.upvalVars            = {};
    self.registerUsageStack   = {};

    self.upvalsProxyLenReturn = math_random(-2 ^ 22, 2 ^ 22);

    local newGlobalScope      = Scope:newGlobal();
    local psc                 = Scope:new(newGlobalScope, nil);

    local _, getfenvVar       = newGlobalScope:resolve("getfenv")
    if not getfenvVar then
        getfenvVar = _ENV
    end



    local _, tableVar = newGlobalScope:resolve("table")

    local _, unpackVar = newGlobalScope:resolve("unpack")
    unpackVar = unpackVar or table.unpack

    local _, envVar = newGlobalScope:resolve("_G")
    local _, newproxyVar = newGlobalScope:resolve("newproxy")
    local _, setmetatableVar = newGlobalScope:resolve("setmetatable")
    local _, getmetatableVar = newGlobalScope:resolve("getmetatable")
    local _, selectVar = newGlobalScope:resolve("select")

    psc:addReferenceToHigherScope(newGlobalScope, getfenvVar)
    psc:addReferenceToHigherScope(newGlobalScope, tableVar)
    psc:addReferenceToHigherScope(newGlobalScope, unpackVar)
    psc:addReferenceToHigherScope(newGlobalScope, envVar)
    psc:addReferenceToHigherScope(newGlobalScope, newproxyVar)
    psc:addReferenceToHigherScope(newGlobalScope, setmetatableVar)
    psc:addReferenceToHigherScope(newGlobalScope, getmetatableVar)

    self.scope                        = Scope:new(psc);
    self.envVar                       = self.scope:addVariable();
    self.containerFuncVar             = self.scope:addVariable();
    self.unpackVar                    = self.scope:addVariable();
    self.newproxyVar                  = self.scope:addVariable();
    self.setmetatableVar              = self.scope:addVariable();
    self.getmetatableVar              = self.scope:addVariable();
    self.selectVar                    = self.scope:addVariable();

    local argVar                      = self.scope:addVariable();

    self.containerFuncScope           = Scope:new(self.scope);
    self.whileScope                   = Scope:new(self.containerFuncScope);

    self.posVar                       = self.containerFuncScope:addVariable();
    self.argsVar                      = self.containerFuncScope:addVariable();
    self.currentUpvaluesVar           = self.containerFuncScope:addVariable();
    self.detectGcCollectVar           = self.containerFuncScope:addVariable();
    self.returnVar                    = self.containerFuncScope:addVariable();

    -- Upvalues Handling
    self.upvaluesTable                = self.scope:addVariable();
    self.upvaluesReferenceCountsTable = self.scope:addVariable();
    self.allocUpvalFunction           = self.scope:addVariable();
    self.currentUpvalId               = self.scope:addVariable();

    -- Gc Handling for Upvalues
    self.upvaluesProxyFunctionVar     = self.scope:addVariable();
    self.upvaluesGcFunctionVar        = self.scope:addVariable();
    self.freeUpvalueFunc              = self.scope:addVariable();

    self.createClosureVars            = {};
    self.createVarargClosureVar       = self.scope:addVariable();
    local createClosureScope          = Scope:new(self.scope);
    local createClosurePosArg         = createClosureScope:addVariable();
    local createClosureUpvalsArg      = createClosureScope:addVariable();
    local createClosureProxyObject    = createClosureScope:addVariable();
    local createClosureFuncVar        = createClosureScope:addVariable();

    local createClosureSubScope       = Scope:new(createClosureScope);

    local upvalEntries                = {};
    local upvalueIds                  = {};
    self.getUpvalueId                 = function(self, scope, id)
        local expression;
        local scopeFuncDepth = self.scopeFunctionDepths[scope];
        if (scopeFuncDepth == 0) then
            if upvalueIds[id] then
                return upvalueIds[id];
            end
            expression = Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {});
        else
            logger:error("Unresolved Upvalue, this error should not occur!");
        end
        upvalEntries[#upvalEntries + 1] = Ast.TableEntry(expression); -- Avoid using table.insert for sequences
        local uid = #upvalEntries;
        upvalueIds[id] = uid;
        return uid;
    end

    -- Reference to Higher Scopes
    createClosureSubScope:addReferenceToHigherScope(self.scope, self.containerFuncVar);
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosurePosArg)
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureUpvalsArg, 1)
    createClosureScope:addReferenceToHigherScope(self.scope, self.upvaluesProxyFunctionVar)
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureProxyObject);

    -- Invoke CompilerB
    self:compileTopNode(ast);

    local functionNodeAssignments = {
        {
            var = Ast.AssignmentVariable(self.scope, self.containerFuncVar),
            val = Ast.FunctionLiteralExpression({
                Ast.VariableExpression(self.containerFuncScope, self.posVar),
                Ast.VariableExpression(self.containerFuncScope, self.argsVar),
                Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
                Ast.VariableExpression(self.containerFuncScope, self.detectGcCollectVar)
            }, self:emitContainerFuncBody()),
        }, {
        var = Ast.AssignmentVariable(self.scope, self.createVarargClosureVar),
        val = Ast.FunctionLiteralExpression({
                Ast.VariableExpression(createClosureScope, createClosurePosArg),
                Ast.VariableExpression(createClosureScope, createClosureUpvalsArg),
            },
            Ast.Block({
                Ast.LocalVariableDeclaration(createClosureScope, {
                    createClosureProxyObject
                }, {
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.upvaluesProxyFunctionVar), {
                        Ast.VariableExpression(createClosureScope, createClosureUpvalsArg)
                    })
                }),
                Ast.LocalVariableDeclaration(createClosureScope, { createClosureFuncVar }, {
                    Ast.FunctionLiteralExpression({
                            Ast.VarargExpression(),
                        },
                        Ast.Block({
                            Ast.ReturnStatement {
                                Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.containerFuncVar), {
                                    Ast.VariableExpression(createClosureScope, createClosurePosArg),
                                    Ast.TableConstructorExpression({ Ast.TableEntry(Ast.VarargExpression()) }),
                                    Ast.VariableExpression(createClosureScope, createClosureUpvalsArg), -- Upvalues
                                    Ast.VariableExpression(createClosureScope, createClosureProxyObject)
                                })
                            }
                        }, createClosureSubScope)
                    ),
                }),
                Ast.ReturnStatement { Ast.VariableExpression(createClosureScope, createClosureFuncVar) },
            }, createClosureScope)
        ),
    }, {
        var = Ast.AssignmentVariable(self.scope, self.upvaluesTable),
        val = Ast.TableConstructorExpression({}),
    }, {
        var = Ast.AssignmentVariable(self.scope, self.upvaluesReferenceCountsTable),
        val = Ast.TableConstructorExpression({}),
    }, {
        var = Ast.AssignmentVariable(self.scope, self.allocUpvalFunction),
        val = self:createAllocUpvalFunction(),
    }, {
        var = Ast.AssignmentVariable(self.scope, self.currentUpvalId),
        val = Ast.NumberExpression(0),
    }, {
        var = Ast.AssignmentVariable(self.scope, self.upvaluesProxyFunctionVar),
        val = self:createUpvaluesProxyFunc(),
    }, {
        var = Ast.AssignmentVariable(self.scope, self.upvaluesGcFunctionVar),
        val = self:createUpvaluesGcFunc(),
    }, {
        var = Ast.AssignmentVariable(self.scope, self.freeUpvalueFunc),
        val = self:createFreeUpvalueFunc(),
    },
    }

    local tbl = {
        Ast.VariableExpression(self.scope, self.containerFuncVar),
        Ast.VariableExpression(self.scope, self.createVarargClosureVar),
        Ast.VariableExpression(self.scope, self.upvaluesTable),
        Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
        Ast.VariableExpression(self.scope, self.allocUpvalFunction),
        Ast.VariableExpression(self.scope, self.currentUpvalId),
        Ast.VariableExpression(self.scope, self.upvaluesProxyFunctionVar),
        Ast.VariableExpression(self.scope, self.upvaluesGcFunctionVar),
        Ast.VariableExpression(self.scope, self.freeUpvalueFunc),
    };
    for i, entry in pairs(self.createClosureVars) do
        table.insert(functionNodeAssignments, entry);
        table.insert(tbl, Ast.VariableExpression(entry.var.scope, entry.var.id));
    end

    util.shuffle(functionNodeAssignments);
    local assignmentStatLhs, assignmentStatRhs = {}, {};
    for i, v in ipairs(functionNodeAssignments) do -- Use ipairs for sequences
        assignmentStatLhs[i] = v.var;
        assignmentStatRhs[i] = v.val;
    end

    -- Emit Code
    local functionNode = Ast.FunctionLiteralExpression({
        Ast.VariableExpression(self.scope, self.envVar),
        Ast.VariableExpression(self.scope, self.unpackVar),
        Ast.VariableExpression(self.scope, self.newproxyVar),
        Ast.VariableExpression(self.scope, self.setmetatableVar),
        Ast.VariableExpression(self.scope, self.getmetatableVar),
        Ast.VariableExpression(self.scope, self.selectVar),
        Ast.VariableExpression(self.scope, argVar),
        unpack(util.shuffle(tbl))
    }, Ast.Block({
        Ast.AssignmentStatement(assignmentStatLhs, assignmentStatRhs),
        Ast.ReturnStatement {
            Ast.FunctionCallExpression(Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.createVarargClosureVar), {
                Ast.NumberExpression(self.startBlockId),
                Ast.TableConstructorExpression(upvalEntries),
            }), { Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.unpackVar), { Ast.VariableExpression(self.scope, argVar) }) }),
        }
    }, self.scope));

    return Ast.TopNode(Ast.Block({
        Ast.ReturnStatement { Ast.FunctionCallExpression(functionNode, {
            Ast.OrExpression(Ast.AndExpression(Ast.VariableExpression(newGlobalScope, getfenvVar or _ENV), Ast.FunctionCallExpression(Ast.VariableExpression(newGlobalScope, getfenvVar or _ENV), {})), Ast.VariableExpression(newGlobalScope, envVar)),
            Ast.OrExpression(Ast.VariableExpression(newGlobalScope, unpackVar), Ast.IndexExpression(Ast.VariableExpression(newGlobalScope, tableVar), Ast.StringExpression("unpack"))),
            Ast.VariableExpression(newGlobalScope, newproxyVar),
            Ast.VariableExpression(newGlobalScope, setmetatableVar),
            Ast.VariableExpression(newGlobalScope, getmetatableVar),
            Ast.VariableExpression(newGlobalScope, selectVar),
            Ast.TableConstructorExpression({
                Ast.TableEntry(Ast.VarargExpression()),
            })
        }) },
    }, psc), newGlobalScope);
end

function CompilerB:getCreateClosureVar(argCount)
    if not self.createClosureVars[argCount] then
        local var = Ast.AssignmentVariable(self.scope, self.scope:addVariable());
        local createClosureScope = Scope:new(self.scope);
        local createClosureSubScope = Scope:new(createClosureScope);

        local createClosurePosArg = createClosureScope:addVariable();
        local createClosureUpvalsArg = createClosureScope:addVariable();
        local createClosureProxyObject = createClosureScope:addVariable();
        local createClosureFuncVar = createClosureScope:addVariable();

        createClosureSubScope:addReferenceToHigherScope(self.scope, self.containerFuncVar);
        createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosurePosArg)
        createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureUpvalsArg, 1)
        createClosureScope:addReferenceToHigherScope(self.scope, self.upvaluesProxyFunctionVar)
        createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureProxyObject);

        local argsTb, argsTb2 = {}, {};
        for i = 1, argCount do
            local arg = createClosureSubScope:addVariable()
            argsTb[i] = Ast.VariableExpression(createClosureSubScope, arg);
            argsTb2[i] = Ast.TableEntry(Ast.VariableExpression(createClosureSubScope, arg));
        end

        local val = Ast.FunctionLiteralExpression({
            Ast.VariableExpression(createClosureScope, createClosurePosArg),
            Ast.VariableExpression(createClosureScope, createClosureUpvalsArg),
        }, Ast.Block({
            Ast.LocalVariableDeclaration(createClosureScope, {
                createClosureProxyObject
            }, {
                Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.upvaluesProxyFunctionVar), {
                    Ast.VariableExpression(createClosureScope, createClosureUpvalsArg)
                })
            }),
            Ast.LocalVariableDeclaration(createClosureScope, { createClosureFuncVar }, {
                Ast.FunctionLiteralExpression(argsTb,
                    Ast.Block({
                        Ast.ReturnStatement {
                            Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.containerFuncVar), {
                                Ast.VariableExpression(createClosureScope, createClosurePosArg),
                                Ast.TableConstructorExpression(argsTb2),
                                Ast.VariableExpression(createClosureScope, createClosureUpvalsArg), -- Upvalues
                                Ast.VariableExpression(createClosureScope, createClosureProxyObject)
                            })
                        }
                    }, createClosureSubScope)
                ),
            }),
            Ast.ReturnStatement { Ast.VariableExpression(createClosureScope, createClosureFuncVar) }
        }, createClosureScope)
        );
        self.createClosureVars[argCount] = {
            var = var,
            val = val,
        }
    end


    local var = self.createClosureVars[argCount].var;
    return var.scope, var.id;
end

function CompilerB:pushRegisterUsageInfo()
    table.insert(self.registerUsageStack, {
        usedRegisters = self.usedRegisters,
        registers = self.registers,
    });
    self.usedRegisters = 0;
    self.registers = {};
end

function CompilerB:popRegisterUsageInfo()
    local info = table.remove(self.registerUsageStack);
    self.usedRegisters = info.usedRegisters;
    self.registers = info.registers;
end

function CompilerB:createUpvaluesGcFunc()
    local scope = Scope:new(self.scope);
    local selfVar = scope:addVariable();

    local iteratorVar = scope:addVariable();
    local valueVar = scope:addVariable();

    local whileScope = Scope:new(scope);
    whileScope:addReferenceToHigherScope(self.scope, self.upvaluesReferenceCountsTable, 3);
    whileScope:addReferenceToHigherScope(scope, valueVar, 3);
    whileScope:addReferenceToHigherScope(scope, iteratorVar, 3);

    local ifScope = Scope:new(whileScope);
    ifScope:addReferenceToHigherScope(self.scope, self.upvaluesReferenceCountsTable, 1);
    ifScope:addReferenceToHigherScope(self.scope, self.upvaluesTable, 1);


    return Ast.FunctionLiteralExpression({ Ast.VariableExpression(scope, selfVar) }, Ast.Block({
        Ast.LocalVariableDeclaration(scope, { iteratorVar, valueVar },
            { Ast.NumberExpression(1), Ast.IndexExpression(Ast.VariableExpression(scope, selfVar),
                Ast.NumberExpression(1)) }),
        Ast.WhileStatement(Ast.Block({
            Ast.AssignmentStatement({
                Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
                    Ast.VariableExpression(scope, valueVar)),
                Ast.AssignmentVariable(scope, iteratorVar),
            }, {
                Ast.SubExpression(
                    Ast.IndexExpression(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
                        Ast.VariableExpression(scope, valueVar)), Ast.NumberExpression(1)),
                Ast.AddExpression(unpack(util.shuffle { Ast.VariableExpression(scope, iteratorVar), Ast.NumberExpression(1) })),
            }),
            Ast.IfStatement(
                Ast.EqualsExpression(unpack(util.shuffle { Ast.IndexExpression(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable), Ast.VariableExpression(scope, valueVar)), Ast.NumberExpression(0) })),
                Ast.Block({
                    Ast.AssignmentStatement({
                        Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
                            Ast.VariableExpression(scope, valueVar)),
                        Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesTable),
                            Ast.VariableExpression(scope, valueVar)),
                    }, {
                        Ast.NilExpression(),
                        Ast.NilExpression(),
                    })
                }, ifScope), {}, nil),
            Ast.AssignmentStatement({
                Ast.AssignmentVariable(scope, valueVar),
            }, {
                Ast.IndexExpression(Ast.VariableExpression(scope, selfVar), Ast.VariableExpression(scope, iteratorVar)),
            }),
        }, whileScope), Ast.VariableExpression(scope, valueVar), scope),
    }, scope));
end

-- Control Flow Flattening/Obfuscation (Cflow)
function CompilerB:createFreeUpvalueFunc()
    local obfuscator = ControlFlowObfuscator:new()
    self.idCounter = (self.idCounter or 0) + 1
    local id = self.idCounter

    local scope = Scope:new(self.scope)
    local argVar = scope:addVariable()
    local ifScope = Scope:new(scope)
    ifScope:addReferenceToHigherScope(scope, argVar, 3)
    scope:addReferenceToHigherScope(self.scope, self.upvaluesReferenceCountsTable, 2)

    local functionLiteralExpression = self:createFunctionLiteralExpressionState0(scope, argVar)

    local obfuscatedCondition = obfuscator:generateNestedObfuscatedCondition(math_random(5, 15))

    local block = {
        id = id,
        statements = {},
        subBlocks = {},
        scope = scope,
        advanceToNextBlock = true,
        condition = obfuscatedCondition,
    }

    self.blocks[#self.blocks + 1] = block

    local registersCount = #self.registers
    local minRegisters = math.min(registersCount, MAX_REGISTERS)
    local loopLimit = registersCount > 1 and math_random(1, minRegisters) or 1
    local numConditions = math.floor(obfuscator:numberMutation())

    local randomValues = {}
    for i = 1, numConditions do
        randomValues[i] = obfuscator:numberMutation()
    end

    if math_random() < cflowFlatteningProbability then
        for i, randomNum in ipairs(randomValues) do
            local condition = obfuscator:generateNestedObfuscatedConditionWithRarelyCheckedConditions(randomNum)
            local bounceCondition = obfuscator:bounce()
            local inliningCondition = obfuscator:inlining()
            local eqmutateCondition = obfuscator:eqmutate()
            if math_random() < RARELY_CHECKED_CONDITION_PROBABILITY then
                for j = 1, numConditions do
                    local deeperCondition = self:createDeeplyNestedConditions(obfuscator, randomValues[j])
                    block.statements[#block.statements + 1] = {
                        op = "if",
                        condition = deeperCondition,
                        thenBlock = j,
                        elseBlock = (j + 1) % numConditions,
                        bounceCondition = bounceCondition,
                        inliningCondition = inliningCondition,
                        eqmutateCondition = eqmutateCondition
                    }
                end
            end
        end

        block.statements = self:shuffle(block.statements)

        local switchCase = {}
        for i, subBlock in ipairs(block.subBlocks) do
            switchCase[i] = subBlock
        end
        block.switchCase = switchCase

        block.selectBlock = function(self, input)
            local index = (input + math.floor(math_random() * #self.switchCase * 2)) % #self.switchCase + 1
            local conditionCheck = math_random() < 0.5 and #self.switchCase or input
            return self.switchCase[index + conditionCheck % #self.switchCase] -- More complex selection
        end

        for i, randomNum in ipairs(randomValues) do
            local condition = obfuscator:generateNestedObfuscatedCondition(randomNum)
            local bounceCondition = obfuscator:bounce()
            local inliningCondition = obfuscator:inlining()
            local eqmutateCondition = obfuscator:eqmutate()
            if math_random() < OPAQUE_PREDICATE_PROBABILITY / 2 then
                block.statements[#block.statements + 1] = {
                    op = "if",
                    condition = condition,
                    thenBlock = i,
                    elseBlock = (i + 1) % registersCount,
                    bounceCondition = bounceCondition,
                    inliningCondition = inliningCondition,
                    eqmutateCondition = eqmutateCondition
                }
            end
        end

        block.statements = self:shuffle(block.statements)
    end

    functionLiteralExpression = self:createFunctionLiteralExpressionState1(scope, argVar, ifScope)

    return functionLiteralExpression
end

function CompilerB:createDeeplyNestedConditions(obfuscator, seed)
    local condition = obfuscator:generateNestedObfuscatedCondition(seed)
    -- Additional nested conditions can be added here based on the complexity required
    return condition
end

function CompilerB:createFunctionLiteralExpressionState0(scope, argVar)
    return Ast.FunctionLiteralExpression({ Ast.VariableExpression(scope, argVar) }, Ast.Block({
        Ast.AssignmentStatement({
            Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
                Ast.VariableExpression(scope, argVar))
        }, {
            Ast.SubExpression(
                Ast.IndexExpression(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
                    Ast.VariableExpression(scope, argVar)), Ast.NumberExpression(1)),
        })
    }, scope))
end

function CompilerB:createFunctionLiteralExpressionState1(scope, argVar, ifScope)
    return Ast.FunctionLiteralExpression({ Ast.VariableExpression(scope, argVar) }, Ast.Block({
        Ast.IfStatement(
            Ast.EqualsExpression(
                Ast.IndexExpression(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
                    Ast.VariableExpression(scope, argVar)), Ast.NumberExpression(0)),
            Ast.Block({
                Ast.AssignmentStatement({
                    Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
                        Ast.VariableExpression(scope, argVar)),
                    Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesTable),
                        Ast.VariableExpression(scope, argVar)),
                }, {
                    Ast.NilExpression(),
                    Ast.NilExpression(),
                })
            }, ifScope), {}, nil)
    }, scope))
end

function CompilerB:createUpvaluesProxyFunc()
    local scope = Scope:new(self.scope);
    scope:addReferenceToHigherScope(self.scope, self.newproxyVar);

    local entriesVar = scope:addVariable();

    local ifScope = Scope:new(scope);
    local proxyVar = ifScope:addVariable();
    local metatableVar = ifScope:addVariable();
    local elseScope = Scope:new(scope);
    ifScope:addReferenceToHigherScope(self.scope, self.newproxyVar);
    ifScope:addReferenceToHigherScope(self.scope, self.getmetatableVar);
    ifScope:addReferenceToHigherScope(self.scope, self.upvaluesGcFunctionVar);
    ifScope:addReferenceToHigherScope(scope, entriesVar);
    elseScope:addReferenceToHigherScope(self.scope, self.setmetatableVar);
    elseScope:addReferenceToHigherScope(scope, entriesVar);
    elseScope:addReferenceToHigherScope(self.scope, self.upvaluesGcFunctionVar);

    local forScope = Scope:new(scope);
    local forArg = forScope:addVariable();
    forScope:addReferenceToHigherScope(self.scope, self.upvaluesReferenceCountsTable, 2);
    forScope:addReferenceToHigherScope(scope, entriesVar, 2);

    return Ast.FunctionLiteralExpression({ Ast.VariableExpression(scope, entriesVar) }, Ast.Block({
        Ast.ForStatement(forScope, forArg, Ast.NumberExpression(1),
            Ast.LenExpression(Ast.VariableExpression(scope, entriesVar)), Ast.NumberExpression(1), Ast.Block({
                Ast.AssignmentStatement({
                    Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
                        Ast.IndexExpression(Ast.VariableExpression(scope, entriesVar),
                            Ast.VariableExpression(forScope, forArg)))
                }, {
                    Ast.AddExpression(unpack(util.shuffle {
                        Ast.IndexExpression(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable), Ast.IndexExpression(Ast.VariableExpression(scope, entriesVar), Ast.VariableExpression(forScope, forArg))),
                        Ast.NumberExpression(1),
                    }))
                })
            }, forScope), scope),
        Ast.IfStatement(Ast.VariableExpression(self.scope, self.newproxyVar), Ast.Block({
            Ast.LocalVariableDeclaration(ifScope, { proxyVar }, {
                Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.newproxyVar), {
                    Ast.BooleanExpression(true)
                }),
            }),
            Ast.LocalVariableDeclaration(ifScope, { metatableVar }, {
                Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.getmetatableVar), {
                    Ast.VariableExpression(ifScope, proxyVar),
                }),
            }),
            Ast.AssignmentStatement({
                Ast.AssignmentIndexing(Ast.VariableExpression(ifScope, metatableVar), Ast.StringExpression("__index")),
                Ast.AssignmentIndexing(Ast.VariableExpression(ifScope, metatableVar), Ast.StringExpression("__gc")),
                Ast.AssignmentIndexing(Ast.VariableExpression(ifScope, metatableVar), Ast.StringExpression("__len")),
            }, {
                Ast.VariableExpression(scope, entriesVar),
                Ast.VariableExpression(self.scope, self.upvaluesGcFunctionVar),
                Ast.FunctionLiteralExpression({}, Ast.Block({
                    Ast.ReturnStatement({ Ast.NumberExpression(self.upvalsProxyLenReturn) })
                }, Scope:new(ifScope))),
            }),
            Ast.ReturnStatement({
                Ast.VariableExpression(ifScope, proxyVar)
            })
        }, ifScope), {}, Ast.Block({
            Ast.ReturnStatement({ Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.setmetatableVar), {
                Ast.TableConstructorExpression({}),
                Ast.TableConstructorExpression({
                    Ast.KeyedTableEntry(Ast.StringExpression("__gc"),
                        Ast.VariableExpression(self.scope, self.upvaluesGcFunctionVar)),
                    Ast.KeyedTableEntry(Ast.StringExpression("__index"), Ast.VariableExpression(scope, entriesVar)),
                    Ast.KeyedTableEntry(Ast.StringExpression("__len"), Ast.FunctionLiteralExpression({}, Ast.Block({
                        Ast.ReturnStatement({ Ast.NumberExpression(self.upvalsProxyLenReturn) })
                    }, Scope:new(ifScope)))),
                })
            }) })
        }, elseScope)),
    }, scope));
end

function CompilerB:createAllocUpvalFunction()
    local scope = Scope:new(self.scope);
    scope:addReferenceToHigherScope(self.scope, self.currentUpvalId, 4);
    scope:addReferenceToHigherScope(self.scope, self.upvaluesReferenceCountsTable, 1);

    return Ast.FunctionLiteralExpression({}, Ast.Block({
        Ast.AssignmentStatement({
            Ast.AssignmentVariable(self.scope, self.currentUpvalId),
        }, {
            Ast.AddExpression(unpack(util.shuffle({
                Ast.VariableExpression(self.scope, self.currentUpvalId),
                Ast.NumberExpression(1),
            }))),
        }
        ),
        Ast.AssignmentStatement({
            Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
                Ast.VariableExpression(self.scope, self.currentUpvalId)),
        }, {
            Ast.NumberExpression(1),
        }),
        Ast.ReturnStatement({
            Ast.VariableExpression(self.scope, self.currentUpvalId),
        })
    }, scope));
end

function CompilerB:emitContainerFuncBody()
    local blocks = {};

    util.shuffle(self.blocks);

    for _, block in ipairs(self.blocks) do
        local id = block.id;
        local blockstats = block.statements;

        -- Shuffle Blockstats
        for i = 2, #blockstats do
            local stat = blockstats[i];
            local reads = stat.reads;
            local writes = stat.writes;
            local maxShift = 0;
            local usesUpvals = stat.usesUpvals;
            for shift = 1, i - 1 do
                local stat2 = blockstats[i - shift];

                if stat2 and stat2.usesUpvals and usesUpvals then
                    break;
                end

                local reads2 = stat2 and stat2.reads;
                local writes2 = stat2 and stat2.writes;
                local f = true;

                if reads2 then
                    for r, b in pairs(reads2) do
                        if (writes[r]) then
                            f = false;
                            break;
                        end
                    end
                end

                if f and writes2 then
                    for r, b in pairs(writes2) do
                        if (writes[r]) then
                            f = false;
                            break;
                        end
                        if (reads[r]) then
                            f = false;
                            break;
                        end
                    end
                end

                if not f then
                    break
                end

                maxShift = shift;
            end

            local shift = math_random(0, maxShift);
            for j = 1, shift do
                blockstats[i - j], blockstats[i - j + 1] = blockstats[i - j + 1], blockstats[i - j];
            end
        end

        blockstats = {};
        for i, stat in ipairs(block.statements) do
            table.insert(blockstats, stat.statement);
        end

        table.insert(blocks, { id = id, block = Ast.Block(blockstats, block.scope) });
    end

    table.sort(blocks, function(a, b)
        return a.id < b.id;
    end);

    local function buildIfBlock(scope, id, lBlock, rBlock)
        return Ast.Block({
            Ast.IfStatement(Ast.LessThanExpression(self:pos(scope), Ast.NumberExpression(id)), lBlock, {}, rBlock),
        }, scope);
    end

    local function buildWhileBody(tb, l, r, pScope, scope)
        local len = r - l + 1;
        if len == 1 then
            tb[r].block.scope:setParent(pScope);
            return tb[r].block;
        elseif len == 0 then
            return nil;
        end

        local mid = l + math.ceil(len / 2);
        local bound
        if tb[mid - 1].id == tb[mid].id then
            -- Handle the case when the ids are equal
            bound = tb[mid - 1].id
        else
            bound = math_random(tb[mid - 1].id + 1, tb[mid].id)
        end
        local ifScope = scope or Scope:new(pScope);

        local lBlock = buildWhileBody(tb, l, mid - 1, ifScope);
        local rBlock = buildWhileBody(tb, mid, r, ifScope);

        return buildIfBlock(ifScope, bound, lBlock, rBlock);
    end

    local whileBody = buildWhileBody(blocks, 1, #blocks, self.containerFuncScope, self.whileScope);

    self.whileScope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar, 1);
    self.whileScope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);

    self.containerFuncScope:addReferenceToHigherScope(self.scope, self.unpackVar);

    local declarations = {
        self.returnVar,
    }

    for i, var in pairs(self.registerVars) do
        if (i ~= MAX_REGS) then
            table.insert(declarations, var);
        end
    end

    local stats = {
        Ast.LocalVariableDeclaration(self.containerFuncScope, util.shuffle(declarations), {}),
        Ast.WhileStatement(whileBody, Ast.VariableExpression(self.containerFuncScope, self.posVar)),
        Ast.AssignmentStatement({
            Ast.AssignmentVariable(self.containerFuncScope, self.posVar)
        }, {
            Ast.LenExpression(Ast.VariableExpression(self.containerFuncScope, self.detectGcCollectVar))
        }),
        Ast.ReturnStatement {
            Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.unpackVar), {
                Ast.VariableExpression(self.containerFuncScope, self.returnVar)
            }),
        }
    }

    if self.maxUsedRegister >= MAX_REGS then
        table.insert(stats, 1,
            Ast.LocalVariableDeclaration(self.containerFuncScope, { self.registerVars[MAX_REGS] },
                { Ast.TableConstructorExpression({}) }));
    end

    return Ast.Block(stats, self.containerFuncScope);
end

function CompilerB:freeRegister(id, force)
    if force or not (self.registers[id] == self.VAR_REGISTER) then
        self.usedRegisters = self.usedRegisters - 1;
        self.registers[id] = false
    end
end

function CompilerB:isVarRegister(id)
    return self.registers[id] == self.VAR_REGISTER;
end

function CompilerB:allocRegister(isVar)
    self.usedRegisters = self.usedRegisters + 1;

    if not isVar then
        -- POS register can be temporarily used
        if not self.registers[self.POS_REGISTER] then
            self.registers[self.POS_REGISTER] = true;
            return self.POS_REGISTER;
        end

        -- RETURN register can be temporarily used
        if not self.registers[self.RETURN_REGISTER] then
            self.registers[self.RETURN_REGISTER] = true;
            return self.RETURN_REGISTER;
        end
    end


    local id = 0;
    if self.usedRegisters < MAX_REGS * MAX_REGS_MUL then
        repeat
            id = math_random(1, MAX_REGS - 1);
        until not self.registers[id];
    else
        repeat
            id = id + 1;
        until not self.registers[id];
    end

    if id > self.maxUsedRegister then
        self.maxUsedRegister = id;
    end

    if (isVar) then
        self.registers[id] = self.VAR_REGISTER;
    else
        self.registers[id] = true
    end
    return id;
end

function CompilerB:isUpvalue(scope, id)
    return self.upvalVars[scope] and self.upvalVars[scope][id];
end

function CompilerB:makeUpvalue(scope, id)
    if (not self.upvalVars[scope]) then
        self.upvalVars[scope] = {}
    end
    self.upvalVars[scope][id] = true;
end

function CompilerB:getVarRegister(scope, id, functionDepth, potentialId)
    if (not self.registersForVar[scope]) then
        self.registersForVar[scope] = {};
        self.scopeFunctionDepths[scope] = functionDepth;
    end

    local reg = self.registersForVar[scope][id];
    if not reg then
        if potentialId and self.registers[potentialId] ~= self.VAR_REGISTER and potentialId ~= self.POS_REGISTER and potentialId ~= self.RETURN_REGISTER then
            self.registers[potentialId] = self.VAR_REGISTER;
            reg = potentialId;
        else
            reg = self:allocRegister(true);
        end
        self.registersForVar[scope][id] = reg;
    end
    return reg;
end

function CompilerB:getRegisterVarId(id)
    local varId = self.registerVars[id];
    if not varId then
        varId = self.containerFuncScope:addVariable();
        self.registerVars[id] = varId;
    end
    return varId;
end

-- Maybe convert ids to strings
function CompilerB:register(scope, id)
    if id == self.POS_REGISTER then
        return self:pos(scope);
    end

    if id == self.RETURN_REGISTER then
        return self:getReturn(scope);
    end

    if id < MAX_REGS then
        local vid = self:getRegisterVarId(id);
        scope:addReferenceToHigherScope(self.containerFuncScope, vid);
        return Ast.VariableExpression(self.containerFuncScope, vid);
    end

    local vid = self:getRegisterVarId(MAX_REGS);
    scope:addReferenceToHigherScope(self.containerFuncScope, vid);
    return Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, vid),
        Ast.NumberExpression((id - MAX_REGS) + 1));
end

function CompilerB:registerList(scope, ids)
    local l = {};
    for i, id in ipairs(ids) do
        table.insert(l, self:register(scope, id));
    end
    return l;
end

function CompilerB:registerAssignment(scope, id)
    if id == self.POS_REGISTER then
        return self:posAssignment(scope);
    end
    if id == self.RETURN_REGISTER then
        return self:returnAssignment(scope);
    end

    if id < MAX_REGS then
        local vid = self:getRegisterVarId(id);
        scope:addReferenceToHigherScope(self.containerFuncScope, vid);
        return Ast.AssignmentVariable(self.containerFuncScope, vid);
    end

    local vid = self:getRegisterVarId(MAX_REGS);
    scope:addReferenceToHigherScope(self.containerFuncScope, vid);
    return Ast.AssignmentIndexing(Ast.VariableExpression(self.containerFuncScope, vid),
        Ast.NumberExpression((id - MAX_REGS) + 1));
end

-- Maybe convert ids to strings
function CompilerB:setRegister(scope, id, val, compundArg)
    if (compundArg) then
        return compundArg(self:registerAssignment(scope, id), val);
    end
    return Ast.AssignmentStatement({
        self:registerAssignment(scope, id)
    }, {
        val
    });
end

function CompilerB:setRegisters(scope, ids, vals)
    local idStats = {};
    for i, id in ipairs(ids) do
        table.insert(idStats, self:registerAssignment(scope, id));
    end

    return Ast.AssignmentStatement(idStats, vals);
end

function CompilerB:copyRegisters(scope, to, from)
    local idStats = {};
    local vals    = {};
    for i, id in ipairs(to) do
        local from = from[i];
        if (from ~= id) then
            table.insert(idStats, self:registerAssignment(scope, id));
            table.insert(vals, self:register(scope, from));
        end
    end

    if (#idStats > 0 and #vals > 0) then
        return Ast.AssignmentStatement(idStats, vals);
    end
end

function CompilerB:resetRegisters()
    self.registers = {};
end

function CompilerB:pos(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.VariableExpression(self.containerFuncScope, self.posVar);
end

function CompilerB:posAssignment(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.AssignmentVariable(self.containerFuncScope, self.posVar);
end

function CompilerB:args(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar);
    return Ast.VariableExpression(self.containerFuncScope, self.argsVar);
end

function CompilerB:unpack(scope)
    scope:addReferenceToHigherScope(self.scope, self.unpackVar);
    return Ast.VariableExpression(self.scope, self.unpackVar);
end

function CompilerB:env(scope)
    scope:addReferenceToHigherScope(self.scope, self.envVar);
    return Ast.VariableExpression(self.scope, self.envVar);
end

function CompilerB:jmp(scope, to)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.AssignmentStatement({ Ast.AssignmentVariable(self.containerFuncScope, self.posVar) }, { to });
end

function CompilerB:setPos(scope, val)
    if not val then
        local v = Ast.IndexExpression(self:env(scope), randomStrings.randomStringNode(math_random(12, 14))); --Ast.NilExpression();
        scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
        return Ast.AssignmentStatement({ Ast.AssignmentVariable(self.containerFuncScope, self.posVar) }, { v });
    end
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.AssignmentStatement({ Ast.AssignmentVariable(self.containerFuncScope, self.posVar) },
        { Ast.NumberExpression(val) or Ast.NilExpression() });
end

function CompilerB:setReturn(scope, val)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar);
    return Ast.AssignmentStatement({ Ast.AssignmentVariable(self.containerFuncScope, self.returnVar) }, { val });
end

function CompilerB:getReturn(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar);
    return Ast.VariableExpression(self.containerFuncScope, self.returnVar);
end

function CompilerB:returnAssignment(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar);
    return Ast.AssignmentVariable(self.containerFuncScope, self.returnVar);
end

function CompilerB:setUpvalueMember(scope, idExpr, valExpr, compoundConstructor)
    scope:addReferenceToHigherScope(self.scope, self.upvaluesTable);
    if compoundConstructor then
        return compoundConstructor(
            Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesTable), idExpr), valExpr);
    end
    return Ast.AssignmentStatement(
        { Ast.AssignmentIndexing(Ast.VariableExpression(self.scope, self.upvaluesTable), idExpr) }, { valExpr });
end

function CompilerB:getUpvalueMember(scope, idExpr)
    scope:addReferenceToHigherScope(self.scope, self.upvaluesTable);
    return Ast.IndexExpression(Ast.VariableExpression(self.scope, self.upvaluesTable), idExpr);
end

function CompilerB:compileTopNode(node)
    -- Initialize necessary lookups for variable access and function identification
    local varAccessLookup = lookupify {
        AstKind.VariableExpression,
        AstKind.AssignmentVariable,
        AstKind.FunctionDeclaration,
        AstKind.LocalFunctionDeclaration,
    }

    local functionLookup = lookupify {
        AstKind.TopNode,
        AstKind.FunctionDeclaration,
        AstKind.LocalFunctionDeclaration,
        AstKind.FunctionLiteralExpression,
    }

    -- Create Initial Block and set active block
    local startBlock = self:createBlock();
    self:setActiveBlock(startBlock);
    local scope = startBlock.scope;
    self.startBlockId = startBlock.id;

    -- Collect Upvalues with adjusted sequence
    visitast(node, function(node, data)
        if varAccessLookup[node.kind] and not node.scope.isGlobal and node.scope.__depth < data.functionData.depth then
            if not self:isUpvalue(node.scope, node.id) then
                self:makeUpvalue(node.scope, node.id);
            end
        end

        if node.kind == AstKind.Block then
            node.scope.__depth = data.functionData.depth;
        end
    end, nil, nil)

    -- Allocate register for varargs and add references to higher scopes
    self.varargReg = self:allocRegister(true);
    scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar);
    scope:addReferenceToHigherScope(self.scope, self.selectVar);
    scope:addReferenceToHigherScope(self.scope, self.unpackVar);

    -- Set vararg register with a simplified AST node creation sequence
    self:addStatement(
        self:setRegister(scope, self.varargReg, Ast.VariableExpression(self.containerFuncScope, self.argsVar)),
        { self.varargReg }, {}, false);

    -- Compile Block with a streamlined approach
    self:compileBlock(node.body, 0);

    -- Adjusted Emit Code Section for final output
    if self.activeBlock.advanceToNextBlock then
        self:addStatement(self:setPos(self.activeBlock.scope, nil), { self.POS_REGISTER }, {}, false);
        self:addStatement(self:setReturn(self.activeBlock.scope, Ast.TableConstructorExpression({})),
            { self.RETURN_REGISTER }, {}, false)
        self.activeBlock.advanceToNextBlock = false;
    end

    -- Reset registers at the end
    self:resetRegisters();
end

function CompilerB:compileFunction(node, funcDepth)
    funcDepth = funcDepth + 1;
    local oldActiveBlock = self.activeBlock;

    local upperVarargReg = self.varargReg;
    self.varargReg = nil;

    -- Adjusted the initialization order of upvalue handling structures for clarity
    local upvalueIds = {};
    local upvalueExpressions = {};
    local usedRegs = {};

    local oldGetUpvalueId = self.getUpvalueId;
    self.getUpvalueId = function(self, scope, id)
        if (not upvalueIds[scope]) then
            upvalueIds[scope] = {};
        end
        if (upvalueIds[scope][id]) then
            return upvalueIds[scope][id];
        end
        local scopeFuncDepth = self.scopeFunctionDepths[scope];
        local expression;
        -- Modified AST node creation sequence for upvalue handling
        if (scopeFuncDepth == funcDepth) then
            expression = Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {});
            oldActiveBlock.scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction);
        elseif (scopeFuncDepth == funcDepth - 1) then
            local varReg = self:getVarRegister(scope, id, scopeFuncDepth, nil);
            expression = self:register(oldActiveBlock.scope, varReg);
            table.insert(usedRegs, varReg);
        else
            local higherId = oldGetUpvalueId(self, scope, id);
            expression = Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
                Ast.NumberExpression(higherId));
            oldActiveBlock.scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar);
        end
        local uid = #upvalueExpressions + 1;
        upvalueIds[scope][id] = uid;
        -- Changed the order of operations for upvalueExpressions to emphasize the creation of AST nodes
        table.insert(upvalueExpressions, Ast.TableEntry(expression));
        return uid;
    end

    local block = self:createBlock();
    self:setActiveBlock(block);
    local scope = self.activeBlock.scope;
    self:pushRegisterUsageInfo();
    for i, arg in ipairs(node.args) do
        -- Reordered AST node creation for argument handling to streamline the process
        if (arg.kind == AstKind.VariableExpression) then
            local argReg = self:getVarRegister(arg.scope, arg.id, funcDepth, nil);
            if (self:isUpvalue(arg.scope, arg.id)) then
                local expression = Ast.FunctionCallExpression(
                    Ast.VariableExpression(self.scope, self.allocUpvalFunction), {});
                scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction);
                self:addStatement(self:setRegister(scope, argReg, expression), { argReg }, {}, false);
                expression = Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.argsVar),
                    Ast.NumberExpression(i));
                self:addStatement(self:setUpvalueMember(scope, self:register(scope, argReg), expression), {}, { argReg },
                    true);
            else
                scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar);
                local expression = Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.argsVar),
                    Ast.NumberExpression(i));
                self:addStatement(self:setRegister(scope, argReg, expression), { argReg }, {}, false);
            end
        else
            -- Simplified vararg handling by adjusting the creation and assignment of AST nodes
            self.varargReg = self:allocRegister(true);
            scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar);
            scope:addReferenceToHigherScope(self.scope, self.selectVar);
            scope:addReferenceToHigherScope(self.scope, self.unpackVar);
            local expression = Ast.TableConstructorExpression({
                Ast.TableEntry(Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.selectVar), {
                    Ast.NumberExpression(i),
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.unpackVar), {
                        Ast.VariableExpression(self.containerFuncScope, self.argsVar),
                    }),
                })),
            });
            self:addStatement(self:setRegister(scope, self.varargReg, expression), { self.varargReg }, {}, false);
        end
    end

    self:compileBlock(node.body, funcDepth);
    if (self.activeBlock.advanceToNextBlock) then
        self:addStatement(self:setPos(self.activeBlock.scope, nil), { self.POS_REGISTER }, {}, false);
        self:addStatement(self:setReturn(self.activeBlock.scope, Ast.TableConstructorExpression({})),
            { self.RETURN_REGISTER }, {}, false);
        self.activeBlock.advanceToNextBlock = false;
    end

    if (self.varargReg) then
        self:freeRegister(self.varargReg, true);
    end
    self.varargReg = upperVarargReg;
    self.getUpvalueId = oldGetUpvalueId;

    self:popRegisterUsageInfo();
    self:setActiveBlock(oldActiveBlock);

    local scope = self.activeBlock.scope;

    local retReg = self:allocRegister(false);

    local isVarargFunction = #node.args > 0 and node.args[#node.args].kind == AstKind.VarargExpression;

    local retrieveExpression
    if isVarargFunction then
        scope:addReferenceToHigherScope(self.scope, self.createVarargClosureVar);
        retrieveExpression = Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.createVarargClosureVar),
            {
                Ast.NumberExpression(block.id),
                Ast.TableConstructorExpression(upvalueExpressions)
            });
    else
        local varScope, var = self:getCreateClosureVar(#node.args + math_random(0, 5));
        scope:addReferenceToHigherScope(varScope, var);
        retrieveExpression = Ast.FunctionCallExpression(Ast.VariableExpression(varScope, var), {
            Ast.NumberExpression(block.id),
            Ast.TableConstructorExpression(upvalueExpressions)
        });
    end

    self:addStatement(self:setRegister(scope, retReg, retrieveExpression), { retReg }, usedRegs, false);
    return retReg;
end

function CompilerB:compileBlock(block, funcDepth)
    for i, stat in ipairs(block.statements) do
        self:compileStatement(stat, funcDepth);
    end

    local scope = self.activeBlock.scope;
    for id, name in ipairs(block.scope.variables) do
        local varReg = self:getVarRegister(block.scope, id, funcDepth, nil);
        if self:isUpvalue(block.scope, id) then
            scope:addReferenceToHigherScope(self.scope, self.freeUpvalueFunc);
            self:addStatement(
                self:setRegister(scope, varReg,
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.freeUpvalueFunc), {
                        self:register(scope, varReg)
                    })), { varReg }, { varReg }, false);
        else
            self:addStatement(self:setRegister(scope, varReg, Ast.NilExpression()), { varReg }, {}, false);
        end
        self:freeRegister(varReg, true);
    end
end

function CompilerB:compileStatement(statement, funcDepth)
    local scope = self.activeBlock.scope;
    -- Return Statement
    if (statement.kind == AstKind.ReturnStatement) then
        local entries = {};
        local regs = {};

        for i, expr in ipairs(statement.args) do
            if i == #statement.args and (expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression or expr.kind == AstKind.VarargExpression) then
                local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1];
                table.insert(entries, Ast.TableEntry(Ast.FunctionCallExpression(
                    self:unpack(scope),
                    { self:register(scope, reg) })));
                table.insert(regs, reg);
            else
                local reg = self:compileExpression(expr, funcDepth, 1)[1];
                table.insert(entries, Ast.TableEntry(self:register(scope, reg)));
                table.insert(regs, reg);
            end
        end

        for _, reg in ipairs(regs) do
            self:freeRegister(reg, false);
        end

        self:addStatement(self:setReturn(scope, Ast.TableConstructorExpression(entries)), { self.RETURN_REGISTER }, regs,
            false);
        self:addStatement(self:setPos(self.activeBlock.scope, nil), { self.POS_REGISTER }, {}, false);
        self.activeBlock.advanceToNextBlock = false;
        return;
    end

    -- Local Variable Declaration
    if (statement.kind == AstKind.LocalVariableDeclaration) then
        local exprregs = {};
        for i, expr in ipairs(statement.expressions) do
            if (i == #statement.expressions and #statement.ids > #statement.expressions) then
                local regs = self:compileExpression(expr, funcDepth, #statement.ids - #statement.expressions + 1);
                for i, reg in ipairs(regs) do
                    table.insert(exprregs, reg);
                end
            else
                if statement.ids[i] or expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression then
                    local reg = self:compileExpression(expr, funcDepth, 1)[1];
                    table.insert(exprregs, reg);
                end
            end
        end

        if #exprregs == 0 then
            for i = 1, #statement.ids do
                table.insert(exprregs, self:compileExpression(Ast.NilExpression(), funcDepth, 1)[1]);
            end
        end

        for i, id in ipairs(statement.ids) do
            if (exprregs[i]) then
                if (self:isUpvalue(statement.scope, id)) then
                    local varreg = self:getVarRegister(statement.scope, id, funcDepth);
                    local varReg = self:getVarRegister(statement.scope, id, funcDepth, nil);
                    scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction);
                    self:addStatement(
                        self:setRegister(scope, varReg,
                            Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {})),
                        { varReg }, {}, false);
                    self:addStatement(
                        self:setUpvalueMember(scope, self:register(scope, varReg), self:register(scope, exprregs[i])), {},
                        { varReg, exprregs[i] }, true);
                    self:freeRegister(exprregs[i], false);
                else
                    local varreg = self:getVarRegister(statement.scope, id, funcDepth, exprregs[i]);
                    self:addStatement(self:copyRegisters(scope, { varreg }, { exprregs[i] }), { varreg }, { exprregs[i] },
                        false);
                    self:freeRegister(exprregs[i], false);
                end
            end
        end

        if not self.scopeFunctionDepths[statement.scope] then
            self.scopeFunctionDepths[statement.scope] = funcDepth;
        end

        return;
    end

    -- Function call Statement
    if (statement.kind == AstKind.FunctionCallStatement) then
        local baseReg = self:compileExpression(statement.base, funcDepth, 1)[1];
        local retReg  = self:allocRegister(false);
        local regs    = {};
        local args    = {};

        for i, expr in ipairs(statement.args) do
            if i == #statement.args and (expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression or expr.kind == AstKind.VarargExpression) then
                local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1];
                table.insert(args, Ast.FunctionCallExpression(
                    self:unpack(scope),
                    { self:register(scope, reg) }));
                table.insert(regs, reg);
            else
                local reg = self:compileExpression(expr, funcDepth, 1)[1];
                table.insert(args, self:register(scope, reg));
                table.insert(regs, reg);
            end
        end

        self:addStatement(
            self:setRegister(scope, retReg, Ast.FunctionCallExpression(self:register(scope, baseReg), args)), { retReg },
            { baseReg, unpack(regs) }, true);
        self:freeRegister(baseReg, false);
        self:freeRegister(retReg, false);
        for i, reg in ipairs(regs) do
            self:freeRegister(reg, false);
        end

        return;
    end

    -- Pass self Function Call Statement
    if (statement.kind == AstKind.PassSelfFunctionCallStatement) then
        local baseReg = self:compileExpression(statement.base, funcDepth, 1)[1];
        local tmpReg  = self:allocRegister(false);
        local args    = { self:register(scope, baseReg) };
        local regs    = { baseReg };

        for i, expr in ipairs(statement.args) do
            if i == #statement.args and (expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression or expr.kind == AstKind.VarargExpression) then
                local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1];
                table.insert(args, Ast.FunctionCallExpression(
                    self:unpack(scope),
                    { self:register(scope, reg) }));
                table.insert(regs, reg);
            else
                local reg = self:compileExpression(expr, funcDepth, 1)[1];
                table.insert(args, self:register(scope, reg));
                table.insert(regs, reg);
            end
        end
        self:addStatement(self:setRegister(scope, tmpReg, Ast.StringExpression(statement.passSelfFunctionName)),
            { tmpReg },
            {}, false);
        self:addStatement(
            self:setRegister(scope, tmpReg,
                Ast.IndexExpression(self:register(scope, baseReg), self:register(scope, tmpReg))),
            { tmpReg }, { tmpReg, baseReg }, false);

        self:addStatement(
            self:setRegister(scope, tmpReg, Ast.FunctionCallExpression(self:register(scope, tmpReg), args)), { tmpReg },
            { tmpReg, unpack(regs) }, true);

        self:freeRegister(tmpReg, false);
        for i, reg in ipairs(regs) do
            self:freeRegister(reg, false);
        end

        return;
    end

    -- Local Function Declaration
    if (statement.kind == AstKind.LocalFunctionDeclaration) then
        if (self:isUpvalue(statement.scope, statement.id)) then
            local varReg = self:getVarRegister(statement.scope, statement.id, funcDepth, nil);
            scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction);
            self:addStatement(
                self:setRegister(scope, varReg,
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {})),
                { varReg },
                {}, false);
            local retReg = self:compileFunction(statement, funcDepth);
            self:addStatement(self:setUpvalueMember(scope, self:register(scope, varReg), self:register(scope, retReg)),
                {}, { varReg, retReg }, true);
            self:freeRegister(retReg, false);
        else
            local retReg = self:compileFunction(statement, funcDepth);
            local varReg = self:getVarRegister(statement.scope, statement.id, funcDepth, retReg);
            self:addStatement(self:copyRegisters(scope, { varReg }, { retReg }), { varReg }, { retReg }, false);
            self:freeRegister(retReg, false);
        end
        return;
    end

    -- Function Declaration
    if (statement.kind == AstKind.FunctionDeclaration) then
        local retReg = self:compileFunction(statement, funcDepth);
        if (#statement.indices > 0) then
            local tblReg;
            if statement.scope.isGlobal then
                tblReg = self:allocRegister(false);
                self:addStatement(
                    self:setRegister(scope, tblReg, Ast.StringExpression(statement.scope:getVariableName(statement.id))),
                    { tblReg }, {}, false);
                self:addStatement(
                    self:setRegister(scope, tblReg, Ast.IndexExpression(self:env(scope), self:register(scope, tblReg))),
                    { tblReg }, { tblReg }, true);
            else
                if self.scopeFunctionDepths[statement.scope] == funcDepth then
                    if self:isUpvalue(statement.scope, statement.id) then
                        tblReg = self:allocRegister(false);
                        local reg = self:getVarRegister(statement.scope, statement.id, funcDepth);
                        self:addStatement(
                            self:setRegister(scope, tblReg, self:getUpvalueMember(scope, self:register(scope, reg))),
                            { tblReg }, { reg }, true);
                    else
                        tblReg = self:getVarRegister(statement.scope, statement.id, funcDepth, retReg);
                    end
                else
                    tblReg = self:allocRegister(false);
                    local upvalId = self:getUpvalueId(statement.scope, statement.id);
                    scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar);
                    self:addStatement(
                        self:setRegister(scope, tblReg,
                            self:getUpvalueMember(scope,
                                Ast.IndexExpression(
                                    Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
                                    Ast.NumberExpression(upvalId)))), { tblReg }, {}, true);
                end
            end

            for i = 1, #statement.indices - 1 do
                local index = statement.indices[i];
                local indexReg = self:compileExpression(Ast.StringExpression(index), funcDepth, 1)[1];
                local tblRegOld = tblReg;
                tblReg = self:allocRegister(false);
                self:addStatement(
                    self:setRegister(scope, tblReg,
                        Ast.IndexExpression(self:register(scope, tblRegOld), self:register(scope, indexReg))), { tblReg },
                    { tblReg, indexReg }, false);
                self:freeRegister(tblRegOld, false);
                self:freeRegister(indexReg, false);
            end

            local index = statement.indices[#statement.indices];
            local indexReg = self:compileExpression(Ast.StringExpression(index), funcDepth, 1)[1];
            self:addStatement(Ast.AssignmentStatement({
                Ast.AssignmentIndexing(self:register(scope, tblReg), self:register(scope, indexReg)),
            }, {
                self:register(scope, retReg),
            }), {}, { tblReg, indexReg, retReg }, true);
            self:freeRegister(indexReg, false);
            self:freeRegister(tblReg, false);
            self:freeRegister(retReg, false);

            return;
        end
        if statement.scope.isGlobal then
            local tmpReg = self:allocRegister(false);
            self:addStatement(
                self:setRegister(scope, tmpReg, Ast.StringExpression(statement.scope:getVariableName(statement.id))),
                { tmpReg }, {}, false);
            self:addStatement(
                Ast.AssignmentStatement({ Ast.AssignmentIndexing(self:env(scope), self:register(scope, tmpReg)) },
                    { self:register(scope, retReg) }), {}, { tmpReg, retReg }, true);
            self:freeRegister(tmpReg, false);
        else
            if self.scopeFunctionDepths[statement.scope] == funcDepth then
                if self:isUpvalue(statement.scope, statement.id) then
                    local reg = self:getVarRegister(statement.scope, statement.id, funcDepth);
                    self:addStatement(
                        self:setUpvalueMember(scope, self:register(scope, reg), self:register(scope, retReg)), {},
                        { reg, retReg }, true);
                else
                    local reg = self:getVarRegister(statement.scope, statement.id, funcDepth, retReg);
                    if reg ~= retReg then
                        self:addStatement(self:setRegister(scope, reg, self:register(scope, retReg)), { reg }, { retReg },
                            false);
                    end
                end
            else
                local upvalId = self:getUpvalueId(statement.scope, statement.id);
                scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar);
                self:addStatement(
                    self:setUpvalueMember(scope,
                        Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
                            Ast.NumberExpression(upvalId)), self:register(scope, retReg)), {}, { retReg }, true);
            end
        end
        self:freeRegister(retReg, false);
        return;
    end

    -- Assignment Statement
    if (statement.kind == AstKind.AssignmentStatement) then
        local exprregs = {};
        local assignmentIndexingRegs = {};
        for i, primaryExpr in ipairs(statement.lhs) do
            if (primaryExpr.kind == AstKind.AssignmentIndexing) then
                assignmentIndexingRegs[i] = {
                    base = self:compileExpression(primaryExpr.base, funcDepth, 1)[1],
                    index = self:compileExpression(primaryExpr.index, funcDepth, 1)[1],
                };
            end
        end

        for i, expr in ipairs(statement.rhs) do
            if (i == #statement.rhs and #statement.lhs > #statement.rhs) then
                local regs = self:compileExpression(expr, funcDepth, #statement.lhs - #statement.rhs + 1);

                for i, reg in ipairs(regs) do
                    if (self:isVarRegister(reg)) then
                        local ro = reg;
                        reg = self:allocRegister(false);
                        self:addStatement(self:copyRegisters(scope, { reg }, { ro }), { reg }, { ro }, false);
                    end
                    table.insert(exprregs, reg);
                end
            else
                if statement.lhs[i] or expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression then
                    local reg = self:compileExpression(expr, funcDepth, 1)[1];
                    if (self:isVarRegister(reg)) then
                        local ro = reg;
                        reg = self:allocRegister(false);
                        self:addStatement(self:copyRegisters(scope, { reg }, { ro }), { reg }, { ro }, false);
                    end
                    table.insert(exprregs, reg);
                end
            end
        end

        for i, primaryExpr in ipairs(statement.lhs) do
            if primaryExpr.kind == AstKind.AssignmentVariable then
                if primaryExpr.scope.isGlobal then
                    local tmpReg = self:allocRegister(false);
                    self:addStatement(
                        self:setRegister(scope, tmpReg,
                            Ast.StringExpression(primaryExpr.scope:getVariableName(primaryExpr.id))), { tmpReg }, {},
                        false);
                    self:addStatement(
                        Ast.AssignmentStatement(
                            { Ast.AssignmentIndexing(self:env(scope), self:register(scope, tmpReg)) },
                            { self:register(scope, exprregs[i]) }), {}, { tmpReg, exprregs[i] }, true);
                    self:freeRegister(tmpReg, false);
                else
                    if self.scopeFunctionDepths[primaryExpr.scope] == funcDepth then
                        if self:isUpvalue(primaryExpr.scope, primaryExpr.id) then
                            local reg = self:getVarRegister(primaryExpr.scope, primaryExpr.id, funcDepth);
                            self:addStatement(
                                self:setUpvalueMember(scope, self:register(scope, reg), self:register(scope, exprregs[i])),
                                {}, { reg, exprregs[i] }, true);
                        else
                            local reg = self:getVarRegister(primaryExpr.scope, primaryExpr.id, funcDepth, exprregs[i]);
                            if reg ~= exprregs[i] then
                                self:addStatement(self:setRegister(scope, reg, self:register(scope, exprregs[i])),
                                    { reg },
                                    { exprregs[i] }, false);
                            end
                        end
                    else
                        local upvalId = self:getUpvalueId(primaryExpr.scope, primaryExpr.id);
                        scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar);
                        self:addStatement(
                            self:setUpvalueMember(scope,
                                Ast.IndexExpression(
                                    Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
                                    Ast.NumberExpression(upvalId)), self:register(scope, exprregs[i])), {},
                            { exprregs[i] },
                            true);
                    end
                end
            elseif primaryExpr.kind == AstKind.AssignmentIndexing then
                local baseReg = assignmentIndexingRegs[i].base;
                local indexReg = assignmentIndexingRegs[i].index;
                self:addStatement(Ast.AssignmentStatement({
                    Ast.AssignmentIndexing(self:register(scope, baseReg), self:register(scope, indexReg))
                }, {
                    self:register(scope, exprregs[i])
                }), {}, { exprregs[i], baseReg, indexReg }, true);
                self:freeRegister(exprregs[i], false);
                self:freeRegister(baseReg, false);
                self:freeRegister(indexReg, false);
            else
                error(string.format("Invalid Assignment lhs: %s", statement.lhs));
            end
        end

        return
    end

    -- If Statement
    if (statement.kind == AstKind.IfStatement) then
        local conditionReg = self:compileExpression(statement.condition, funcDepth, 1)[1];
        local finalBlock = self:createBlock();

        local nextBlock
        if statement.elsebody or #statement.elseifs > 0 then
            nextBlock = self:createBlock();
        else
            nextBlock = finalBlock;
        end
        local innerBlock = self:createBlock();

        self:addStatement(
            self:setRegister(scope, self.POS_REGISTER,
                Ast.OrExpression(
                    Ast.AndExpression(self:register(scope, conditionReg), Ast.NumberExpression(innerBlock.id)),
                    Ast.NumberExpression(nextBlock.id))), { self.POS_REGISTER }, { conditionReg }, false);

        self:freeRegister(conditionReg, false);

        self:setActiveBlock(innerBlock);
        scope = innerBlock.scope
        self:compileBlock(statement.body, funcDepth);
        self:addStatement(self:setRegister(scope, self.POS_REGISTER, Ast.NumberExpression(finalBlock.id)),
            { self.POS_REGISTER }, {}, false);

        for i, eif in ipairs(statement.elseifs) do
            self:setActiveBlock(nextBlock);
            conditionReg = self:compileExpression(eif.condition, funcDepth, 1)[1];
            local innerBlock = self:createBlock();
            if statement.elsebody or i < #statement.elseifs then
                nextBlock = self:createBlock();
            else
                nextBlock = finalBlock;
            end
            local scope = self.activeBlock.scope;
            self:addStatement(
                self:setRegister(scope, self.POS_REGISTER,
                    Ast.OrExpression(
                        Ast.AndExpression(self:register(scope, conditionReg), Ast.NumberExpression(innerBlock.id)),
                        Ast.NumberExpression(nextBlock.id))), { self.POS_REGISTER }, { conditionReg }, false);

            self:freeRegister(conditionReg, false);

            self:setActiveBlock(innerBlock);
            scope = innerBlock.scope;
            self:compileBlock(eif.body, funcDepth);
            self:addStatement(self:setRegister(scope, self.POS_REGISTER, Ast.NumberExpression(finalBlock.id)),
                { self.POS_REGISTER }, {}, false);
        end

        if statement.elsebody then
            self:setActiveBlock(nextBlock);
            self:compileBlock(statement.elsebody, funcDepth);
            self:addStatement(self:setRegister(scope, self.POS_REGISTER, Ast.NumberExpression(finalBlock.id)),
                { self.POS_REGISTER }, {}, false);
        end

        self:setActiveBlock(finalBlock);

        return;
    end

    -- Do Statement
    if (statement.kind == AstKind.DoStatement) then
        self:compileBlock(statement.body, funcDepth);
        return;
    end

    -- While Statement
    if (statement.kind == AstKind.WhileStatement) then
        local innerBlock = self:createBlock();
        local finalBlock = self:createBlock();
        local checkBlock = self:createBlock();

        statement.__start_block = checkBlock;
        statement.__final_block = finalBlock;

        self:addStatement(self:setPos(scope, checkBlock.id), { self.POS_REGISTER }, {}, false);

        self:setActiveBlock(checkBlock);
        local scope = self.activeBlock.scope;
        local conditionReg = self:compileExpression(statement.condition, funcDepth, 1)[1];
        self:addStatement(
            self:setRegister(scope, self.POS_REGISTER,
                Ast.OrExpression(
                    Ast.AndExpression(self:register(scope, conditionReg), Ast.NumberExpression(innerBlock.id)),
                    Ast.NumberExpression(finalBlock.id))), { self.POS_REGISTER }, { conditionReg }, false);
        self:freeRegister(conditionReg, false);

        self:setActiveBlock(innerBlock);
        local scope = self.activeBlock.scope;
        self:compileBlock(statement.body, funcDepth);
        self:addStatement(self:setPos(scope, checkBlock.id), { self.POS_REGISTER }, {}, false);
        self:setActiveBlock(finalBlock);
        return;
    end

    -- Repeat Statement
    if (statement.kind == AstKind.RepeatStatement) then
        local innerBlock = self:createBlock();
        local finalBlock = self:createBlock();
        local checkBlock = self:createBlock();
        statement.__start_block = checkBlock;
        statement.__final_block = finalBlock;

        local conditionReg = self:compileExpression(statement.condition, funcDepth, 1)[1];
        self:addStatement(self:setRegister(scope, self.POS_REGISTER, Ast.NumberExpression(innerBlock.id)),
            { self.POS_REGISTER }, {}, false);
        self:freeRegister(conditionReg, false);

        self:setActiveBlock(innerBlock);
        self:compileBlock(statement.body, funcDepth);
        local scope = self.activeBlock.scope
        self:addStatement(self:setPos(scope, checkBlock.id), { self.POS_REGISTER }, {}, false);
        self:setActiveBlock(checkBlock);
        local scope = self.activeBlock.scope;
        local conditionReg = self:compileExpression(statement.condition, funcDepth, 1)[1];
        self:addStatement(
            self:setRegister(scope, self.POS_REGISTER,
                Ast.OrExpression(
                    Ast.AndExpression(self:register(scope, conditionReg), Ast.NumberExpression(finalBlock.id)),
                    Ast.NumberExpression(innerBlock.id))), { self.POS_REGISTER }, { conditionReg }, false);
        self:freeRegister(conditionReg, false);

        self:setActiveBlock(finalBlock);

        return;
    end

    -- For Statement
    if (statement.kind == AstKind.ForStatement) then
        local checkBlock = self:createBlock();
        local innerBlock = self:createBlock();
        local finalBlock = self:createBlock();

        statement.__start_block = checkBlock;
        statement.__final_block = finalBlock;

        local posState = self.registers[self.POS_REGISTER];
        self.registers[self.POS_REGISTER] = self.VAR_REGISTER;

        local initialReg = self:compileExpression(statement.initialValue, funcDepth, 1)[1];

        local finalExprReg = self:compileExpression(statement.finalValue, funcDepth, 1)[1];
        local finalReg = self:allocRegister(false);
        self:addStatement(self:copyRegisters(scope, { finalReg }, { finalExprReg }), { finalReg }, { finalExprReg },
            false);
        self:freeRegister(finalExprReg);

        local incrementExprReg = self:compileExpression(statement.incrementBy, funcDepth, 1)[1];
        local incrementReg = self:allocRegister(false);
        self:addStatement(self:copyRegisters(scope, { incrementReg }, { incrementExprReg }), { incrementReg },
            { incrementExprReg }, false);
        self:freeRegister(incrementExprReg);

        local tmpReg = self:allocRegister(false);
        self:addStatement(self:setRegister(scope, tmpReg, Ast.NumberExpression(0)), { tmpReg }, {}, false);
        local incrementIsNegReg = self:allocRegister(false);
        self:addStatement(
            self:setRegister(scope, incrementIsNegReg,
                Ast.LessThanExpression(self:register(scope, incrementReg), self:register(scope, tmpReg))),
            { incrementIsNegReg }, { incrementReg, tmpReg }, false);
        self:freeRegister(tmpReg);

        local currentReg = self:allocRegister(true);
        self:addStatement(
            self:setRegister(scope, currentReg,
                Ast.SubExpression(self:register(scope, initialReg), self:register(scope, incrementReg))), { currentReg },
            { initialReg, incrementReg }, false);
        self:freeRegister(initialReg);

        self:addStatement(self:jmp(scope, Ast.NumberExpression(checkBlock.id)), { self.POS_REGISTER }, {}, false);

        self:setActiveBlock(checkBlock);

        scope = checkBlock.scope;
        self:addStatement(
            self:setRegister(scope, currentReg,
                Ast.AddExpression(self:register(scope, currentReg), self:register(scope, incrementReg))), { currentReg },
            { currentReg, incrementReg }, false);
        local tmpReg1 = self:allocRegister(false);
        local tmpReg2 = self:allocRegister(false);
        self:addStatement(self:setRegister(scope, tmpReg2, Ast.NotExpression(self:register(scope, incrementIsNegReg))),
            { tmpReg2 }, { incrementIsNegReg }, false);
        self:addStatement(
            self:setRegister(scope, tmpReg1,
                Ast.LessThanOrEqualsExpression(self:register(scope, currentReg), self:register(scope, finalReg))),
            { tmpReg1 },
            { currentReg, finalReg }, false);
        self:addStatement(
            self:setRegister(scope, tmpReg1,
                Ast.AndExpression(self:register(scope, tmpReg2), self:register(scope, tmpReg1))),
            { tmpReg1 }, { tmpReg1, tmpReg2 }, false);
        self:addStatement(
            self:setRegister(scope, tmpReg2,
                Ast.GreaterThanOrEqualsExpression(self:register(scope, currentReg), self:register(scope, finalReg))),
            { tmpReg2 }, { currentReg, finalReg }, false);
        self:addStatement(
            self:setRegister(scope, tmpReg2,
                Ast.AndExpression(self:register(scope, incrementIsNegReg), self:register(scope, tmpReg2))), { tmpReg2 },
            { tmpReg2, incrementIsNegReg }, false);
        self:addStatement(
            self:setRegister(scope, tmpReg1,
                Ast.OrExpression(self:register(scope, tmpReg2), self:register(scope, tmpReg1))),
            { tmpReg1 }, { tmpReg1, tmpReg2 }, false);
        self:freeRegister(tmpReg2);
        tmpReg2 = self:compileExpression(Ast.NumberExpression(innerBlock.id), funcDepth, 1)[1];
        self:addStatement(
            self:setRegister(scope, self.POS_REGISTER,
                Ast.AndExpression(self:register(scope, tmpReg1), self:register(scope, tmpReg2))), { self.POS_REGISTER },
            { tmpReg1, tmpReg2 }, false);
        self:freeRegister(tmpReg2);
        self:freeRegister(tmpReg1);
        tmpReg2 = self:compileExpression(Ast.NumberExpression(finalBlock.id), funcDepth, 1)[1];
        self:addStatement(
            self:setRegister(scope, self.POS_REGISTER,
                Ast.OrExpression(self:register(scope, self.POS_REGISTER), self:register(scope, tmpReg2))),
            { self.POS_REGISTER }, { self.POS_REGISTER, tmpReg2 }, false);
        self:freeRegister(tmpReg2);

        self:setActiveBlock(innerBlock);
        scope = innerBlock.scope;
        self.registers[self.POS_REGISTER] = posState;

        local varReg = self:getVarRegister(statement.scope, statement.id, funcDepth, nil);

        if (self:isUpvalue(statement.scope, statement.id)) then
            scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction);
            self:addStatement(
                self:setRegister(scope, varReg,
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {})),
                { varReg },
                {}, false);
            self:addStatement(
                self:setUpvalueMember(scope, self:register(scope, varReg), self:register(scope, currentReg)), {},
                { varReg, currentReg }, true);
        else
            self:addStatement(self:setRegister(scope, varReg, self:register(scope, currentReg)), { varReg },
                { currentReg },
                false);
        end


        self:compileBlock(statement.body, funcDepth);
        self:addStatement(self:setRegister(scope, self.POS_REGISTER, Ast.NumberExpression(checkBlock.id)),
            { self.POS_REGISTER }, {}, false);

        self.registers[self.POS_REGISTER] = self.VAR_REGISTER;
        self:freeRegister(finalReg);
        self:freeRegister(incrementIsNegReg);
        self:freeRegister(incrementReg);
        self:freeRegister(currentReg, true);

        self.registers[self.POS_REGISTER] = posState;
        self:setActiveBlock(finalBlock);

        return;
    end

    -- For in Statement
    if (statement.kind == AstKind.ForInStatement) then
        local expressionsLength = #statement.expressions;
        local exprregs = {};
        for i, expr in ipairs(statement.expressions) do
            if (i == expressionsLength and expressionsLength < 3) then
                local regs = self:compileExpression(expr, funcDepth, 4 - expressionsLength);
                for i = 1, 4 - expressionsLength do
                    table.insert(exprregs, regs[i]);
                end
            else
                if i <= 3 then
                    table.insert(exprregs, self:compileExpression(expr, funcDepth, 1)[1])
                else
                    self:freeRegister(self:compileExpression(expr, funcDepth, 1)[1], false);
                end
            end
        end

        for i, reg in ipairs(exprregs) do
            if reg and self.registers[reg] ~= self.VAR_REGISTER and reg ~= self.POS_REGISTER and reg ~= self.RETURN_REGISTER then
                self.registers[reg] = self.VAR_REGISTER;
            else
                exprregs[i] = self:allocRegister(true);
                self:addStatement(self:copyRegisters(scope, { exprregs[i] }, { reg }), { exprregs[i] }, { reg }, false);
            end
        end

        local checkBlock = self:createBlock();
        local bodyBlock = self:createBlock();
        local finalBlock = self:createBlock();

        statement.__start_block = checkBlock;
        statement.__final_block = finalBlock;

        self:addStatement(self:setPos(scope, checkBlock.id), { self.POS_REGISTER }, {}, false);

        self:setActiveBlock(checkBlock);
        local scope = self.activeBlock.scope;

        local varRegs = {};
        for i, id in ipairs(statement.ids) do
            varRegs[i] = self:getVarRegister(statement.scope, id, funcDepth)
        end

        self:addStatement(Ast.AssignmentStatement({
            self:registerAssignment(scope, exprregs[3]),
            varRegs[2] and self:registerAssignment(scope, varRegs[2]),
        }, {
            Ast.FunctionCallExpression(self:register(scope, exprregs[1]), {
                self:register(scope, exprregs[2]),
                self:register(scope, exprregs[3]),
            })
        }), { exprregs[3], varRegs[2] }, { exprregs[1], exprregs[2], exprregs[3] }, true);

        self:addStatement(Ast.AssignmentStatement({
            self:posAssignment(scope)
        }, {
            Ast.OrExpression(Ast.AndExpression(self:register(scope, exprregs[3]), Ast.NumberExpression(bodyBlock.id)),
                Ast.NumberExpression(finalBlock.id))
        }), { self.POS_REGISTER }, { exprregs[3] }, false);

        self:setActiveBlock(bodyBlock);
        local scope = self.activeBlock.scope;
        self:addStatement(self:copyRegisters(scope, { varRegs[1] }, { exprregs[3] }), { varRegs[1] }, { exprregs[3] },
            false);
        for i = 3, #varRegs do
            self:addStatement(self:setRegister(scope, varRegs[i], Ast.NilExpression()), { varRegs[i] }, {}, false);
        end

        -- Upvalue fix
        for i, id in ipairs(statement.ids) do
            if (self:isUpvalue(statement.scope, id)) then
                local varreg = varRegs[i];
                local tmpReg = self:allocRegister(false);
                scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction);
                self:addStatement(
                    self:setRegister(scope, tmpReg,
                        Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {})),
                    { tmpReg }, {}, false);
                self:addStatement(
                    self:setUpvalueMember(scope, self:register(scope, tmpReg), self:register(scope, varreg)), {},
                    { tmpReg, varreg }, true);
                self:addStatement(self:copyRegisters(scope, { varreg }, { tmpReg }), { varreg }, { tmpReg }, false);
                self:freeRegister(tmpReg, false);
            end
        end

        self:compileBlock(statement.body, funcDepth);
        self:addStatement(self:setPos(scope, checkBlock.id), { self.POS_REGISTER }, {}, false);
        self:setActiveBlock(finalBlock);

        for i, reg in ipairs(exprregs) do
            self:freeRegister(exprregs[i], true)
        end

        return;
    end

    -- Do Statement
    if (statement.kind == AstKind.DoStatement) then
        self:compileBlock(statement.body, funcDepth);
        return;
    end

    -- Break Statement
    if (statement.kind == AstKind.BreakStatement) then
        local toFreeVars = {};
        local statScope;
        repeat
            statScope = statScope and statScope.parentScope or statement.scope;
            for id, name in ipairs(statScope.variables) do
                table.insert(toFreeVars, {
                    scope = statScope,
                    id = id,
                });
            end
        until statScope == statement.loop.body.scope;

        for i, var in pairs(toFreeVars) do
            local varScope, id = var.scope, var.id;
            local varReg = self:getVarRegister(varScope, id, nil, nil);
            if self:isUpvalue(varScope, id) then
                scope:addReferenceToHigherScope(self.scope, self.freeUpvalueFunc);
                self:addStatement(
                    self:setRegister(scope, varReg,
                        Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.freeUpvalueFunc), {
                            self:register(scope, varReg)
                        })), { varReg }, { varReg }, false);
            else
                self:addStatement(self:setRegister(scope, varReg, Ast.NilExpression()), { varReg }, {}, false);
            end
        end

        self:addStatement(self:setPos(scope, statement.loop.__final_block.id), { self.POS_REGISTER }, {}, false);
        self.activeBlock.advanceToNextBlock = false;
        return;
    end

    -- Check if the statement is within the current or parent block
    local function isInCurrentOrParentBlock(statement)
        local currentScope = self.currentScope
        while currentScope do
            if currentScope == statement.scope then
                return true
            end
            currentScope = currentScope.parent
        end
        return false
    end

    -- Label Statement
    if (statement.kind == AstKind.LabelStatement) then
        if isInCurrentOrParentBlock(statement) then
            local labelScope, labelID = statement.scope, statement.id;
            self:addStatement(Ast.LabelStatement(labelID, labelScope, statement.label), {}, {}, false);
        end
        return;
    end

    -- Goto Statement
    if (statement.kind == AstKind.GotoStatement) then
        if isInCurrentOrParentBlock(statement) then
            local labelScope, labelID = statement.scope, statement.id;
            self:addStatement(Ast.GotoStatement(labelID, labelScope, statement.label), {}, {}, false);
        end
        return;
    end

    -- Contiue Statement
    if (statement.kind == AstKind.ContinueStatement) then
        local toFreeVars = {};
        local statScope;
        repeat
            statScope = statScope and statScope.parentScope or statement.scope;
            for id, name in pairs(statScope.variables) do
                table.insert(toFreeVars, {
                    scope = statScope,
                    id = id,
                });
            end
        until statScope == statement.loop.body.scope;

        for i, var in ipairs(toFreeVars) do
            local varScope, id = var.scope, var.id;
            local varReg = self:getVarRegister(varScope, id, nil, nil);
            if self:isUpvalue(varScope, id) then
                scope:addReferenceToHigherScope(self.scope, self.freeUpvalueFunc);
                self:addStatement(
                    self:setRegister(scope, varReg,
                        Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.freeUpvalueFunc), {
                            self:register(scope, varReg)
                        })), { varReg }, { varReg }, false);
            else
                self:addStatement(self:setRegister(scope, varReg, Ast.NilExpression()), { varReg }, {}, false);
            end
        end

        self:addStatement(self:setPos(scope, statement.loop.__start_block.id), { self.POS_REGISTER }, {}, false);
        self.activeBlock.advanceToNextBlock = false;
        return;
    end

    -- Compund Statements
    local compoundConstructors = {
        [AstKind.CompoundAddStatement] = Ast.CompoundAddStatement,
        [AstKind.CompoundSubStatement] = Ast.CompoundSubStatement,
        [AstKind.CompoundMulStatement] = Ast.CompoundMulStatement,
        [AstKind.CompoundDivStatement] = Ast.CompoundDivStatement,
        [AstKind.CompoundModStatement] = Ast.CompoundModStatement,
        [AstKind.CompoundPowStatement] = Ast.CompoundPowStatement,
        [AstKind.CompoundConcatStatement] = Ast.CompoundConcatStatement,
    }
    if compoundConstructors[statement.kind] then
        local compoundConstructor = compoundConstructors[statement.kind];
        if statement.lhs.kind == AstKind.AssignmentIndexing then
            local indexing = statement.lhs;
            local baseReg = self:compileExpression(indexing.base, funcDepth, 1)[1];
            local indexReg = self:compileExpression(indexing.index, funcDepth, 1)[1];
            local valueReg = self:compileExpression(statement.rhs, funcDepth, 1)[1];

            self:addStatement(
                compoundConstructor(
                    Ast.AssignmentIndexing(self:register(scope, baseReg), self:register(scope, indexReg)),
                    self:register(scope, valueReg)), {}, { baseReg, indexReg, valueReg }, true);
        else
            local valueReg = self:compileExpression(statement.rhs, funcDepth, 1)[1];
            local primaryExpr = statement.lhs;
            if primaryExpr.scope.isGlobal then
                local tmpReg = self:allocRegister(false);
                self:addStatement(
                    self:setRegister(scope, tmpReg,
                        Ast.StringExpression(primaryExpr.scope:getVariableName(primaryExpr.id))),
                    { tmpReg }, {}, false);
                self:addStatement(
                    Ast.AssignmentStatement({ Ast.AssignmentIndexing(self:env(scope), self:register(scope, tmpReg)) },
                        { self:register(scope, valueReg) }), {}, { tmpReg, valueReg }, true);
                self:freeRegister(tmpReg, false);
            else
                if self.scopeFunctionDepths[primaryExpr.scope] == funcDepth then
                    if self:isUpvalue(primaryExpr.scope, primaryExpr.id) then
                        local reg = self:getVarRegister(primaryExpr.scope, primaryExpr.id, funcDepth);
                        self:addStatement(
                            self:setUpvalueMember(scope, self:register(scope, reg), self:register(scope, valueReg),
                                compoundConstructor), {}, { reg, valueReg }, true);
                    else
                        local reg = self:getVarRegister(primaryExpr.scope, primaryExpr.id, funcDepth, valueReg);
                        if reg ~= valueReg then
                            self:addStatement(
                                self:setRegister(scope, reg, self:register(scope, valueReg), compoundConstructor),
                                { reg },
                                { valueReg }, false);
                        end
                    end
                else
                    local upvalId = self:getUpvalueId(primaryExpr.scope, primaryExpr.id);
                    scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar);
                    self:addStatement(
                        self:setUpvalueMember(scope,
                            Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
                                Ast.NumberExpression(upvalId)), self:register(scope, valueReg), compoundConstructor), {},
                        { valueReg }, true);
                end
            end
        end
        return;
    end

    logger:error(string.format("%s is not a compileable statement!", statement.kind));
end

function CompilerB:compileExpression(expression, funcDepth, numReturns)
    local scope = self.activeBlock.scope;


    -- String Expression
    if (expression.kind == AstKind.StringExpression) then
        local regs = {};
        for i = 1, numReturns, 1 do
            regs[i] = self:allocRegister();
            if (i == 1) then
                self:addStatement(self:setRegister(scope, regs[i], Ast.StringExpression(expression.value)), { regs[i] },
                    {}, false);
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    end

    -- Number Expression
    if (expression.kind == AstKind.NumberExpression) then
        local regs = {};
        for i = 1, numReturns do
            regs[i] = self:allocRegister();
            if (i == 1) then
                self:addStatement(self:setRegister(scope, regs[i], Ast.NumberExpression(expression.value)), { regs[i] },
                    {}, false);
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    end

    -- Boolean Expression
    if (expression.kind == AstKind.BooleanExpression) then
        local regs = {};
        for i = 1, numReturns do
            regs[i] = self:allocRegister();
            if (i == 1) then
                self:addStatement(self:setRegister(scope, regs[i], Ast.BooleanExpression(expression.value)), { regs[i] },
                    {}, false);
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    end

    -- Nil Expression
    if (expression.kind == AstKind.NilExpression) then
        local regs = {};
        for i = 1, numReturns do
            regs[i] = self:allocRegister();
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
        end
        return regs;
    end

    -- Variable Expression
    if (expression.kind == AstKind.VariableExpression) then
        local regs = {};
        for i = 1, numReturns do
            if (i == 1) then
                if (expression.scope.isGlobal) then
                    -- Global Variable
                    regs[i] = self:allocRegister(false);
                    local tmpReg = self:allocRegister(false);
                    self:addStatement(
                        self:setRegister(scope, tmpReg,
                            Ast.StringExpression(expression.scope:getVariableName(expression.id))),
                        { tmpReg }, {}, false);
                    self:addStatement(
                        self:setRegister(scope, regs[i],
                            Ast.IndexExpression(self:env(scope), self:register(scope, tmpReg))),
                        { regs[i] }, { tmpReg }, true);
                    self:freeRegister(tmpReg, false);
                else
                    -- Local Variable
                    if (self.scopeFunctionDepths[expression.scope] == funcDepth) then
                        if self:isUpvalue(expression.scope, expression.id) then
                            local reg = self:allocRegister(false);
                            local varReg = self:getVarRegister(expression.scope, expression.id, funcDepth, nil);
                            self:addStatement(
                                self:setRegister(scope, reg, self:getUpvalueMember(scope, self:register(scope, varReg))),
                                { reg }, { varReg }, true);
                            regs[i] = reg;
                        else
                            regs[i] = self:getVarRegister(expression.scope, expression.id, funcDepth, nil);
                        end
                    else
                        local reg = self:allocRegister(false);
                        local upvalId = self:getUpvalueId(expression.scope, expression.id);
                        scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar);
                        self:addStatement(
                            self:setRegister(scope, reg,
                                self:getUpvalueMember(scope,
                                    Ast.IndexExpression(
                                        Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
                                        Ast.NumberExpression(upvalId)))), { reg }, {}, true);
                        regs[i] = reg;
                    end
                end
            else
                regs[i] = self:allocRegister();
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    end

    -- Function call Expression
    if (expression.kind == AstKind.FunctionCallExpression) then
        local baseReg   = self:compileExpression(expression.base, funcDepth, 1)[1];

        local retRegs   = {};
        local returnAll = numReturns == self.RETURN_ALL;
        if returnAll then
            retRegs[1] = self:allocRegister(false);
        else
            for i = 1, numReturns do
                retRegs[i] = self:allocRegister(false);
            end
        end

        local regs = {};
        local args = {};
        for i, expr in ipairs(expression.args) do
            if i == #expression.args and (expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression or expr.kind == AstKind.VarargExpression) then
                local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1];
                table.insert(args, Ast.FunctionCallExpression(
                    self:unpack(scope),
                    { self:register(scope, reg) }));
                table.insert(regs, reg);
            else
                local reg = self:compileExpression(expr, funcDepth, 1)[1];
                table.insert(args, self:register(scope, reg));
                table.insert(regs, reg);
            end
        end

        if (returnAll) then
            self:addStatement(
                self:setRegister(scope, retRegs[1],
                    Ast.TableConstructorExpression { Ast.TableEntry(Ast.FunctionCallExpression(self:register(scope, baseReg), args)) }),
                { retRegs[1] }, { baseReg, unpack(regs) }, true);
        else
            if (numReturns > 1) then
                local tmpReg = self:allocRegister(false);

                self:addStatement(
                    self:setRegister(scope, tmpReg,
                        Ast.TableConstructorExpression { Ast.TableEntry(Ast.FunctionCallExpression(self:register(scope, baseReg), args)) }),
                    { tmpReg }, { baseReg, unpack(regs) }, true);

                for i, reg in ipairs(retRegs) do
                    self:addStatement(
                        self:setRegister(scope, reg,
                            Ast.IndexExpression(self:register(scope, tmpReg), Ast.NumberExpression(i))), { reg },
                        { tmpReg },
                        false);
                end

                self:freeRegister(tmpReg, false);
            else
                self:addStatement(
                    self:setRegister(scope, retRegs[1], Ast.FunctionCallExpression(self:register(scope, baseReg), args)),
                    { retRegs[1] }, { baseReg, unpack(regs) }, true);
            end
        end

        self:freeRegister(baseReg, false);
        for i, reg in ipairs(regs) do
            self:freeRegister(reg, false);
        end

        return retRegs;
    end


    -- Pass self Function Call Expression
    if (expression.kind == AstKind.PassSelfFunctionCallExpression) then
        local baseReg   = self:compileExpression(expression.base, funcDepth, 1)[1];
        local retRegs   = {};
        local returnAll = numReturns == self.RETURN_ALL;
        if returnAll then
            retRegs[1] = self:allocRegister(false);
        else
            for i = 1, numReturns do
                retRegs[i] = self:allocRegister(false);
            end
        end

        local args = { self:register(scope, baseReg) };
        local regs = { baseReg };

        for i, expr in ipairs(expression.args) do
            if i == #expression.args and (expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression or expr.kind == AstKind.VarargExpression) then
                local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1];
                table.insert(args, Ast.FunctionCallExpression(
                    self:unpack(scope),
                    { self:register(scope, reg) }));
                table.insert(regs, reg);
            else
                local reg = self:compileExpression(expr, funcDepth, 1)[1];
                table.insert(args, self:register(scope, reg));
                table.insert(regs, reg);
            end
        end

        if (returnAll or numReturns > 1) then
            local tmpReg = self:allocRegister(false);

            self:addStatement(self:setRegister(scope, tmpReg, Ast.StringExpression(expression.passSelfFunctionName)),
                { tmpReg }, {}, false);
            self:addStatement(
                self:setRegister(scope, tmpReg,
                    Ast.IndexExpression(self:register(scope, baseReg), self:register(scope, tmpReg))), { tmpReg },
                { baseReg, tmpReg }, false);

            if returnAll then
                self:addStatement(
                    self:setRegister(scope, retRegs[1],
                        Ast.TableConstructorExpression { Ast.TableEntry(Ast.FunctionCallExpression(self:register(scope, tmpReg), args)) }),
                    { retRegs[1] }, { tmpReg, unpack(regs) }, true);
            else
                self:addStatement(
                    self:setRegister(scope, tmpReg,
                        Ast.TableConstructorExpression { Ast.TableEntry(Ast.FunctionCallExpression(self:register(scope, tmpReg), args)) }),
                    { tmpReg }, { tmpReg, unpack(regs) }, true);

                for i, reg in ipairs(retRegs) do
                    self:addStatement(
                        self:setRegister(scope, reg,
                            Ast.IndexExpression(self:register(scope, tmpReg), Ast.NumberExpression(i))), { reg },
                        { tmpReg },
                        false);
                end
            end

            self:freeRegister(tmpReg, false);
        else
            local tmpReg = retRegs[1] or self:allocRegister(false);

            self:addStatement(self:setRegister(scope, tmpReg, Ast.StringExpression(expression.passSelfFunctionName)),
                { tmpReg }, {}, false);
            self:addStatement(
                self:setRegister(scope, tmpReg,
                    Ast.IndexExpression(self:register(scope, baseReg), self:register(scope, tmpReg))), { tmpReg },
                { baseReg, tmpReg }, false);

            self:addStatement(
                self:setRegister(scope, retRegs[1], Ast.FunctionCallExpression(self:register(scope, tmpReg), args)),
                { retRegs[1] }, { baseReg, unpack(regs) }, true);
        end

        for i, reg in ipairs(regs) do
            self:freeRegister(reg, false);
        end

        return retRegs;
    end

    -- Index Expression
    if (expression.kind == AstKind.IndexExpression) then
        local regs = {};
        for i = 1, numReturns do
            regs[i] = self:allocRegister();
            if (i == 1) then
                local baseReg = self:compileExpression(expression.base, funcDepth, 1)[1];
                local indexReg = self:compileExpression(expression.index, funcDepth, 1)[1];

                self:addStatement(
                    self:setRegister(scope, regs[i],
                        Ast.IndexExpression(self:register(scope, baseReg), self:register(scope, indexReg))), { regs[i] },
                    { baseReg, indexReg }, true);
                self:freeRegister(baseReg, false);
                self:freeRegister(indexReg, false)
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    end

    -- Binary Operations
    if (self.BIN_OPS[expression.kind]) then
        local regs = {};
        for i = 1, numReturns do
            regs[i] = self:allocRegister();
            if (i == 1) then
                local lhsReg = self:compileExpression(expression.lhs, funcDepth, 1)[1];
                local rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1];

                self:addStatement(
                    self:setRegister(scope, regs[i],
                        Ast[expression.kind](self:register(scope, lhsReg), self:register(scope, rhsReg))), { regs[i] },
                    { lhsReg, rhsReg }, true);
                self:freeRegister(rhsReg, false);
                self:freeRegister(lhsReg, false)
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    end

    if (expression.kind == AstKind.NotExpression) then
        local regs = {};
        for i = 1, numReturns do
            regs[i] = self:allocRegister();
            if (i == 1) then
                local rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1];

                self:addStatement(self:setRegister(scope, regs[i], Ast.NotExpression(self:register(scope, rhsReg))),
                    { regs[i] }, { rhsReg }, false);
                self:freeRegister(rhsReg, false)
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    end

    if (expression.kind == AstKind.NegateExpression) then
        local regs = {};
        for i = 1, numReturns do
            regs[i] = self:allocRegister();
            if (i == 1) then
                local rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1];

                self:addStatement(self:setRegister(scope, regs[i], Ast.NegateExpression(self:register(scope, rhsReg))),
                    { regs[i] }, { rhsReg }, true);
                self:freeRegister(rhsReg, false)
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    end

    if (expression.kind == AstKind.LenExpression) then
        local regs = {};
        local i = 1;
        regs[i] = self:allocRegister();
        if (i == 1) then
            local rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1];
            self:addStatement(self:setRegister(scope, regs[i], Ast.LenExpression(self:register(scope, rhsReg))),
                { regs[i] }, { rhsReg }, true);
            self:freeRegister(rhsReg, false)
        end
        i = i + 1;
        while i <= numReturns do
            regs[i] = self:allocRegister();
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            i = i + 1;
        end
        return regs;
    end

    if (expression.kind == AstKind.OrExpression) then
        local posRegister = self.POS_REGISTER
        local varRegister = self.VAR_REGISTER
        local posState = self.registers[posRegister]
        self.registers[posRegister] = varRegister

        local regs = {}
        for i = 1, numReturns do
            regs[i] = self:allocRegister()
            if (i ~= 1) then
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false)
            end
        end

        local resReg = regs[1]
        local tmpReg

        if posState then
            tmpReg = self:allocRegister(false)
            self:addStatement(self:copyRegisters(scope, { tmpReg }, { posRegister }), { tmpReg },
                { posRegister }, false)
        end

        local lhsReg = self:compileExpression(expression.lhs, funcDepth, 1)[1]
        local lhsRegister = self:register(scope, lhsReg)
        if (expression.rhs.isConstant) then
            local rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1]
            self:addStatement(
                self:setRegister(scope, resReg,
                    Ast.OrExpression(lhsRegister, self:register(scope, rhsReg))),
                { resReg }, { lhsReg, rhsReg }, false)
            if tmpReg then
                self:freeRegister(tmpReg, false)
            end
            self:freeRegister(lhsReg, false)
            self:freeRegister(rhsReg, false)
            return regs
        end

        local block1, block2 = self:createBlock(), self:createBlock()
        self:addStatement(self:copyRegisters(scope, { resReg }, { lhsReg }), { resReg }, { lhsReg }, false)
        self:addStatement(
            self:setRegister(scope, posRegister,
                Ast.OrExpression(Ast.AndExpression(lhsRegister, Ast.NumberExpression(block2.id)),
                    Ast.NumberExpression(block1.id))), { posRegister }, { lhsReg }, false)
        self:freeRegister(lhsReg, false)

        do
            self:setActiveBlock(block1)
            local scope = block1.scope
            local rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1]
            self:addStatement(self:copyRegisters(scope, { resReg }, { rhsReg }), { resReg }, { rhsReg }, false)
            self:freeRegister(rhsReg, false)
            self:addStatement(self:setRegister(scope, posRegister, Ast.NumberExpression(block2.id)),
                { posRegister }, {}, false)
        end

        self.registers[posRegister] = posState

        self:setActiveBlock(block2)
        scope = block2.scope

        if tmpReg then
            self:addStatement(self:copyRegisters(scope, { posRegister }, { tmpReg }), { posRegister },
                { tmpReg }, false)
            self:freeRegister(tmpReg, false)
        end

        return regs
    end

    if (expression.kind == AstKind.AndExpression) then
        local posState = self.registers[self.POS_REGISTER]
        self.registers[self.POS_REGISTER] = self.VAR_REGISTER

        local regs = {}
        for i = 1, numReturns do
            regs[i] = self:allocRegister()
            if (i ~= 1) then
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false)
            end
        end

        local resReg = regs[1]
        local tmpReg

        if posState then
            tmpReg = self:allocRegister(false)
            self:addStatement(self:copyRegisters(scope, { tmpReg }, { self.POS_REGISTER }), { tmpReg },
                { self.POS_REGISTER }, false)
        end

        local lhsReg = self:compileExpression(expression.lhs, funcDepth, 1)[1]
        local lhsRegScope = self:register(scope, lhsReg)
        if (expression.rhs.isConstant) then
            local rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1]
            self:addStatement(
                self:setRegister(scope, resReg,
                    Ast.AndExpression(lhsRegScope, self:register(scope, rhsReg))),
                { resReg }, { lhsReg, rhsReg }, false)
            if tmpReg then
                self:freeRegister(tmpReg, false)
            end
            self:freeRegister(lhsReg, false)
            self:freeRegister(rhsReg, false)
            return regs
        end

        local block1, block2 = self:createBlock(), self:createBlock()
        self:addStatement(self:copyRegisters(scope, { resReg }, { lhsReg }), { resReg }, { lhsReg }, false)
        self:addStatement(
            self:setRegister(scope, self.POS_REGISTER,
                Ast.OrExpression(Ast.AndExpression(lhsRegScope, Ast.NumberExpression(block1.id)),
                    Ast.NumberExpression(block2.id))), { self.POS_REGISTER }, { lhsReg }, false)
        self:freeRegister(lhsReg, false)

        self:setActiveBlock(block1)
        scope = block1.scope
        self:addStatement(self:copyRegisters(scope, { resReg }, { lhsReg }), { resReg }, { lhsReg }, false)
        self:addStatement(self:setRegister(scope, self.POS_REGISTER, Ast.NumberExpression(block2.id)),
            { self.POS_REGISTER }, {}, false)

        self.registers[self.POS_REGISTER] = posState

        self:setActiveBlock(block2)
        scope = block2.scope

        if tmpReg then
            self:addStatement(self:copyRegisters(scope, { self.POS_REGISTER }, { tmpReg }), { self.POS_REGISTER },
                { tmpReg }, false)
            self:freeRegister(tmpReg, false)
        end

        return regs
    end


    if (expression.kind == AstKind.TableConstructorExpression) then
        local regs = {};
        local entries = {};
        local entryRegs = {};
        for i = 1, numReturns do
            regs[i] = self:allocRegister();
            if (i == 1) then
                for i, entry in ipairs(expression.entries) do
                    local value = entry.value;
                    if (entry.kind == AstKind.TableEntry) then
                        local reg;
                        if i == #expression.entries and (value.kind == AstKind.FunctionCallExpression or value.kind == AstKind.PassSelfFunctionCallExpression or value.kind == AstKind.VarargExpression) then
                            reg = self:compileExpression(entry.value, funcDepth, self.RETURN_ALL)[1];
                            table.insert(entries, Ast.TableEntry(Ast.FunctionCallExpression(
                                self:unpack(scope),
                                { self:register(scope, reg) })));
                        else
                            reg = self:compileExpression(entry.value, funcDepth, 1)[1];
                            table.insert(entries, Ast.TableEntry(self:register(scope, reg)));
                        end
                        table.insert(entryRegs, reg);
                    else
                        local keyReg = self:compileExpression(entry.key, funcDepth, 1)[1];
                        local valReg = self:compileExpression(entry.value, funcDepth, 1)[1];
                        table.insert(entries,
                            Ast.KeyedTableEntry(self:register(scope, keyReg), self:register(scope, valReg)));
                        table.insert(entryRegs, valReg);
                        table.insert(entryRegs, keyReg);
                    end
                end
                self:addStatement(self:setRegister(scope, regs[i], Ast.TableConstructorExpression(entries)), { regs[i] },
                    entryRegs, false);
                for i, reg in ipairs(entryRegs) do
                    self:freeRegister(reg, false);
                end
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    end

    if (expression.kind == AstKind.TableConstructorExpression) then
        local regs = {};
        local funcRefs = {
            compileExpression = self.compileExpression,
            register = self.register,
            setRegister = self
                .setRegister,
            freeRegister = self.freeRegister
        };

        -- Randomize the order of entries
        local entries = expression.entries
        for i = #entries, 2, -1 do
            local j = math_random(i)                        -- get random index
            entries[i], entries[j] = entries[j], entries[i] -- swap elements
        end

        for i = 1, numReturns do
            regs[i] = self:allocRegister();
            if (i == 1) then
                local processedEntries = {};
                for i, entry in ipairs(entries) do
                    local reg = funcRefs.compileExpression(self, entry.value, funcDepth, 1)[1];
                    if (entry.kind == AstKind.TableEntry) then
                        local value = entry.value;
                        if i == #entries and (value.kind == AstKind.FunctionCallExpression or value.kind == AstKind.PassSelfFunctionCallExpression or value.kind == AstKind.VarargExpression) then
                            table.insert(processedEntries, Ast.TableEntry(Ast.FunctionCallExpression(
                                self:unpack(scope),
                                { funcRefs.register(self, scope, reg) })));
                        else
                            table.insert(processedEntries, Ast.TableEntry(funcRefs.register(self, scope, reg)));
                        end
                    else
                        local keyReg = funcRefs.compileExpression(self, entry.key, funcDepth, 1)[1];
                        local valReg = funcRefs.register(self, scope, reg);
                        table.insert(processedEntries,
                            Ast.KeyedTableEntry(funcRefs.register(self, scope, keyReg), valReg));
                        funcRefs.freeRegister(self, keyReg, false);
                        funcRefs.freeRegister(self, valReg, false);
                    end
                    funcRefs.freeRegister(self, reg, false);
                end
                funcRefs.setRegister(self, scope, regs[i], Ast.TableConstructorExpression(processedEntries));
            else
                funcRefs.setRegister(self, scope, regs[i], Ast.NilExpression());
            end
        end
        return regs;
    end

    if (expression.kind == AstKind.FunctionLiteralExpression) then
        local regs = {};
        for i = 1, numReturns do
            if (i == 1) then
                regs[i] = self:compileFunction(expression, funcDepth);
            else
                regs[i] = self:allocRegister();
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), { regs[i] }, {}, false);
            end
        end
        return regs;
    elseif (expression.kind == AstKind.VarargExpression) then
        if numReturns == self.RETURN_ALL then
            return { self.varargReg };
        end
        local regs = {};
        for i = 1, numReturns do
            regs[i] = self:allocRegister(false);
            self:addStatement(
                self:setRegister(scope, regs[i],
                    Ast.IndexExpression(self:register(scope, self.varargReg), Ast.NumberExpression(i))), { regs[i] },
                { self.varargReg }, false);
        end
        return regs;
    else
        logger:error(string.format("%s is not an compliable expression!", expression.kind));
    end
end

return CompilerB;
