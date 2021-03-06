-- | Operations necessary to update nodes
module Juvix.Backends.LLVM.Codegen.Graph where

import Juvix.Backends.LLVM.Codegen.Block as Block
import Juvix.Backends.LLVM.Codegen.Types as Types
import Juvix.Library hiding (Type, local)
import qualified Juvix.Library.HashMap as Map
import qualified LLVM.AST as AST
import qualified LLVM.AST.Constant as C
import qualified LLVM.AST.IntegerPredicate as IntPred
import qualified LLVM.AST.Name as Name
import qualified LLVM.AST.Operand as Operand
import qualified LLVM.AST.Type as Type

-- TODO ∷ abstract out getElementPointer and load into a single operation

--------------------------------------------------------------------------------
-- Main Functions
--------------------------------------------------------------------------------

-- TODO ∷ delNodes, deleteRewire, deleteEdge, allocaNode in full

-- TODO ∷ abstract over the define pattern seen below?

link ∷
  ( HasThrow "err" Errors m,
    HasState "blockCount" Int m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "moduleDefinitions" [AST.Definition] m,
    HasState "names" Names m,
    HasState "symtab" (Map.HashMap Symbol Operand.Operand) m
  ) ⇒
  m Operand.Operand
link = Block.defineFunction Type.void "link" args $
  do
    setPort ("node_1", "port_1") ("node_2", "port_2")
    setPort ("node_2", "port_2") ("node_1", "port_1")
    retNull
  where
    args =
      [ (nodeType, "node_1"),
        (numPorts, "port_1"),
        (nodeType, "node_2"),
        (numPorts, "port_2")
      ]

-- perform offsets

isBothPrimary ∷
  ( HasThrow "err" Errors m,
    HasState "blockCount" Int m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "moduleDefinitions" [AST.Definition] m,
    HasState "names" Names m,
    HasState "symtab" (Map.HashMap Symbol Operand.Operand) m,
    HasState "typTab" TypeTable m,
    HasState "varTab" VariantToType m
  ) ⇒
  m Operand.Operand
isBothPrimary = Block.defineFunction Types.bothPrimary "is_both_primary" args $
  do
    -- TODO ∷ should this call be abstracted somewhere?!
    -- Why should Ι allocate for every port?!
    mainPort ← mainPort
    -- TODO ∷ Make sure findEdge is in the environment
    edge ← Block.externf "find_edge"
    nodePtr ← Block.externf "node_ptr"
    node ← load nodeType nodePtr
    port ← call portType edge (Block.emptyArgs [node, mainPort])
    otherNodePtr ← loadElementPtr $
      Types.Minimal
        { Types.type' = nodePointer,
          Types.address' = port,
          Types.indincies' = Block.constant32List [0, 0]
        }
    -- convert ptrs to ints
    nodeInt ← ptrToInt nodePtr pointerSize
    otherNodeInt ← ptrToInt otherNodePtr pointerSize
    -- compare the pointers to see if they are the same
    cmp ← icmp IntPred.EQ nodeInt otherNodeInt
    return' ← Block.alloca Types.bothPrimary
    tag ← getIsPrimaryEle return'
    nod ← getPrimaryNode return'
    store tag cmp
    store nod otherNodePtr
    ret return'
  where
    args = [(nodePointer, "node_ptr")]

-- The logic assumes that the operation always succeeds
findEdge ∷
  ( HasThrow "err" Errors m,
    HasState "blockCount" Int m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "moduleDefinitions" [AST.Definition] m,
    HasState "names" Names m,
    HasState "symtab" (Map.HashMap Symbol Operand.Operand) m
  ) ⇒
  m Operand.Operand
findEdge = Block.defineFunction Types.portType "find_edge" args $
  do
    node ← Block.externf "node"
    pNum ← Block.externf "port"
    portPtr ← getPort node pNum
    port ← load portType portPtr
    otherPtr ← portPointsTo port
    other ← load portType otherPtr
    ret other
  where
    args = [(nodeType, "node"), (numPorts, "port")]

-- TODO ∷ allocaPorts, allocaPortType, allocaData, allocaNodeType
-- Name           | Arguments
-- allocaNodeType : two array args
-- allocaPortType : nodePointer ∧ numPorts
-- allocaPorts    : variable args of ports
-- allocaData     : variable args of dataType

allocaNode ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m
  ) ⇒
  m Operand.Operand
allocaNode = alloca nodeType

-- H variants below mean that we are able to allocate from Haskell and
-- need not make a function

-- TODO ∷ could be storing data wrong... find out
allocaNodeH ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "typTab" TypeTable m,
    HasState "varTab" VariantToType m
  ) ⇒
  [Maybe Operand.Operand] →
  [Maybe Operand.Operand] →
  m Operand.Operand
allocaNodeH mPorts mData = do
  node ← allocaNode
  portSize ← allocaNumPortNum (fromIntegral $ length mPorts)
  ports ← allocaPortsH mPorts
  data' ← allocaDataH mData
  tagPtr ← getElementPtr $
    Types.Minimal
      { Types.type' = Types.numPorts,
        Types.address' = node,
        Types.indincies' = Block.constant32List [0, 0]
      }
  store tagPtr portSize
  portPtr ← getElementPtr $
    Types.Minimal
      { Types.type' = Types.portData, -- do I really want to say size 0?
        Types.address' = node,
        Types.indincies' = Block.constant32List [0, 1]
      }
  store portPtr ports
  dataPtr ← getElementPtr $
    Types.Minimal
      { Types.type' = Type.ArrayType 0 Types.dataType, -- do I really want to say size 0?
        Types.address' = node,
        Types.indincies' = Block.constant32List [0, 2]
      }
  store dataPtr data'
  pure node

allocaGenH ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m
  ) ⇒
  [Maybe Operand.Operand] →
  Type.Type →
  m Operand.Operand
allocaGenH mPortData type' = do
  ports ← alloca (Type.ArrayType (fromIntegral len) type')
  traverse_
    ( \(p, i) →
        case p of
          Nothing → pure ()
          Just p → do
            ptr ← getElementPtr $
              Types.Minimal
                { Types.type' = type',
                  Types.address' = ports,
                  Types.indincies' = Block.constant32List [0, i]
                }
            store ptr p
    )
    (zip mPortData [0 ..])
  pure ports
  where
    len = fromIntegral (length mPortData)

allocaPortsH,
  allocaDataH ∷
    ( HasThrow "err" Errors m,
      HasState "blocks" (Map.HashMap Name.Name BlockState) m,
      HasState "count" Word m,
      HasState "currentBlock" Name.Name m
    ) ⇒
    [Maybe Operand.Operand] →
    m Operand.Operand
allocaPortsH mPorts = allocaGenH mPorts Types.portType
allocaDataH mPorts = allocaGenH mPorts Types.dataType

-- TODO ∷ figure out var args
-- not needed right away as we know how many args we need from Haskell
allocaPorts = Block.defineFunctionVarArgs portArrayLen "alloca_ports" args $
  do
    undefined
  where
    args = [(portType, "P")]

-- derived from the core functions

linkConnectedPort ∷
  ( HasThrow "err" Errors m,
    HasState "blockCount" Int m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "moduleDefinitions" [AST.Definition] m,
    HasState "names" Names m,
    HasState "symtab" SymbolTable m
  ) ⇒
  m Operand.Operand
linkConnectedPort = Block.defineFunction Type.void "link_connected_port" args $
  do
    edge ← Block.externf "find_edge"
    link ← Block.externf "link"
    (nOld, pOld) ← (,) <$> Block.externf "node_old" <*> Block.externf "port_old"
    (nNew, pNew) ← (,) <$> Block.externf "node_new" <*> Block.externf "port_new"
    oldPointsTo ← call Types.portType edge (Block.emptyArgs [nOld, pOld])
    -- TODO ∷ Abstract out this bit ---------------------------------------------
    let intoGen typ num = loadElementPtr $
          Types.Minimal
            { Types.type' = typ,
              Types.address' = oldPointsTo,
              Types.indincies' = Block.constant32List [0, num]
            }
    numPointsTo ← intoGen numPorts 1
    nodePointsToPtr ← intoGen nodePointer 0
    nodePointsTo ← load nodeType nodePointsToPtr
    -- End Abstracting out bits -------------------------------------------------
    _ ← call Type.void link (Block.emptyArgs [nNew, pNew, numPointsTo, nodePointsTo])
    retNull
  where
    args =
      [ (nodeType, "node_old"),
        (numPorts, "port_old"),
        (nodeType, "node_new"),
        (numPorts, "port_new")
      ]

rewire ∷
  ( HasThrow "err" Errors m,
    HasState "blockCount" Int m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "moduleDefinitions" [AST.Definition] m,
    HasState "names" Names m,
    HasState "symtab" SymbolTable m
  ) ⇒
  m Operand.Operand
rewire = Block.defineFunction Type.void "rewire" args $
  do
    edge ← Block.externf "find_edge"
    relink ← Block.externf "link_connected_port"
    -- TODO ∷ Abstract out this bit ---------------------------------------------
    (n1, p1) ← (,) <$> Block.externf "node_one" <*> Block.externf "port_one"
    (n2, p2) ← (,) <$> Block.externf "node_two" <*> Block.externf "port_two"
    oldPointsTo ← call Types.portType edge (Block.emptyArgs [n1, p1])
    let intoGen typ num = loadElementPtr $
          Types.Minimal
            { Types.type' = typ,
              Types.address' = oldPointsTo,
              Types.indincies' = Block.constant32List [0, num]
            }
    numPointsTo ← intoGen numPorts 1
    nodePointsToPtr ← intoGen nodePointer 0
    nodePointsTo ← load nodeType nodePointsToPtr
    -- End Abstracting out bits -------------------------------------------------
    _ ← call Type.void relink (Block.emptyArgs [n2, p2, numPointsTo, nodePointsTo])
    retNull
  where
    args =
      [ (nodeType, "node_one"),
        (numPorts, "port_one"),
        (nodeType, "node_two"),
        (numPorts, "port_two")
      ]

delNode = undefined

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Logic for setPort expanded

-- 1. getElementPointer the tag
-- Int ⇒
-- \ 1. times offset by this number (* Don't really have to do it! *)
-- \ 2. grab the node from here
-- \ 3. do operation
-- Int* ⇒
-- \ 1. deref the Int
-- \ 2. times the offset by this deref (* Don't really have to do it! *)
-- \ 3. grab node from  here
-- \ 4. do operation

setPort ∷
  ( HasThrow "err" Errors m,
    HasState "blockCount" Int m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "names" Names m,
    HasState "symtab" SymbolTable m
  ) ⇒
  (Name.Name, Name.Name) →
  (Name.Name, Name.Name) →
  m ()
setPort (n1, p1) (n2, p2) = do
  (no1, po1) ← (,) <$> Block.externf n1 <*> Block.externf p1
  (no2, po2) ← (,) <$> Block.externf n2 <*> Block.externf p2
  -- Grab the int value of port 1
  portLocation ← getPort no1 po1
  p2Ptr ← newPortType no2 po2
  store portLocation p2Ptr
  pure ()

newPortType ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m
  ) ⇒
  Operand.Operand →
  Operand.Operand →
  m Operand.Operand
newPortType node offset = do
  newPort ← alloca portType
  -- This is a ptr to a ptr
  nodePtr ← getElementPtr $
    Types.Minimal
      { Types.type' = nodePointer,
        Types.address' = newPort,
        Types.indincies' = Block.constant32List [0, 0]
      }
  offsetPtr ← getElementPtr $
    Types.Minimal
      { Types.type' = numPorts,
        Types.address' = newPort,
        Types.indincies' = Block.constant32List [0, 1]
      }
  -- allocate pointer to the node
  givenNodePtr ← alloca nodePointer
  placeToStoreNode ← getElementPtr $
    Types.Minimal
      { Types.type' = nodeType,
        Types.address' = givenNodePtr,
        Types.indincies' = Block.constant32List [0, 0]
      }
  -- Store the node to it
  store placeToStoreNode node
  -- now store the pointer to the newPort
  store nodePtr givenNodePtr
  -- store the offset
  store offsetPtr offset
  pure newPort

getPort ∷
  ( HasThrow "err" Errors m,
    HasState "blockCount" Int m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "names" Names m
  ) ⇒
  Operand.Operand →
  Operand.Operand →
  m Operand.Operand
getPort node port = do
  intOfNumPorts portPointer port $ \value → do
    ports ← loadElementPtr $
      Types.Minimal
        { Types.type' = portData,
          Types.address' = node,
          Types.indincies' = Block.constant32List [0, 1]
        }
    -- allocate the new pointer
    getElementPtr $
      Types.Minimal
        { Types.type' = portType,
          Types.address' = ports,
          -- TODO ∷ Ι may have to count size here, I don't think so?
          Types.indincies' =
            [ Operand.ConstantOperand (C.Int 32 0),
              value
            ]
        }

-- | 'intOfNumPorts' generates an int of two different sizes to be used in cont logic
-- the type referees to the final type in the cont logic
intOfNumPorts ∷
  ( HasThrow "err" Errors m,
    HasState "blockCount" Int m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "names" Names m
  ) ⇒
  Type.Type →
  Operand.Operand →
  (Operand.Operand → m Operand.Operand) →
  m Operand.Operand
intOfNumPorts typ numPort cont = do
  -- grab the tag from the numPort
  tag ← Block.loadElementPtr $
    Types.Minimal
      { Types.type' = Type.i1,
        Types.address' = numPort,
        Types.indincies' = Block.constant32List [0, 0]
      }
  generateIf typ tag smallBranch largeBranch
  where
    smallBranch = branchGen numPortsSmall numPortsSmallValue return

    largeBranch = branchGen numPortsLarge numPortsLargeValuePtr $
      \vPtr →
        Block.loadElementPtr $
          Types.Minimal
            { Types.type' = numPortsLargeValue,
              Types.address' = vPtr,
              Types.indincies' = Block.constant32List [0, 0]
            }

    -- Generic logic
    branchGen variant variantType extraDeref = do
      casted ← bitCast numPort (varientToType variant)
      value ← Block.loadElementPtr $
        Types.Minimal
          { Types.type' = variantType,
            Types.address' = casted,
            Types.indincies' = Block.constant32List [0, 1]
          }
      -- Does nothing for the small case
      value ← extraDeref value
      cont value

-- | 'portPointsTo' is a function which grabs the portType of the node a portType points to
portPointsTo ∷
  ( HasThrow "err" Errors m,
    HasState "blockCount" Int m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "names" Names m
  ) ⇒
  Operand.Operand →
  m Operand.Operand
portPointsTo (portType ∷ Operand.Operand) = do
  -- TODO ∷ see if there is any special logic for packed Types
  -- Do I have to index by size?
  nodePtr ← Block.loadElementPtr $
    Types.Minimal
      { Types.type' = nodePointer,
        Types.address' = portType,
        Types.indincies' = Block.constant32List [0, 0]
      }
  -- get the node which it points to
  nodeType ← loadElementPtr $
    Types.Minimal
      { Types.type' = nodeType,
        Types.address' = nodePtr,
        Types.indincies' = Block.constant32List [0, 0]
      }
  -- Get the numPort
  numPort ← Block.loadElementPtr $
    Types.Minimal
      { Types.type' = numPorts,
        Types.address' = portType,
        -- Index may change due to being packed
        Types.indincies' = Block.constant32List [0, 1]
      }
  getPort nodeType numPort

-- | Allocates a 'numPorts'
allocaNumPortsStatic ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "typTab" TypeTable m,
    HasState "varTab" VariantToType m
  ) ⇒
  Bool →
  Operand.Operand →
  m Operand.Operand
allocaNumPortsStatic (isLarge ∷ Bool) (value ∷ Operand.Operand) =
  -- Call Block.createVariant
  -- Issue is that I need to register this sum type in the map
  -- else it is an error.
  -- see if this is okay, if not make custom logic just for the
  -- sums to create the language
  case isLarge of
    False →
      -- TODO ∷ register this variant
      Block.createVariant "numPorts_small" [value]
    True → do
      -- Allocate a pointer to the value
      ptr ← alloca nodePointer
      store ptr value
      -- TODO ∷ register this variant
      Block.createVariant "numPorts_large" [ptr]

-- | like 'allocaNumPortStatic', except it takes a number and allocates the correct operand
allocaNumPortNum ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m,
    HasState "typTab" TypeTable m,
    HasState "varTab" VariantToType m
  ) ⇒
  Integer →
  m Operand.Operand
allocaNumPortNum n
  | n <= 2 ^ (Types.numPortsSize - 1 ∷ Integer) =
    allocaNumPortsStatic False (Operand.ConstantOperand (C.Int 16 n))
  | otherwise =
    allocaNumPortsStatic True (Operand.ConstantOperand (C.Int 64 n))

--------------------------------------------------------------------------------
-- Port Aliases
--------------------------------------------------------------------------------

mainPort,
  auxiliary1,
  auxiliary2,
  auxiliary3,
  auxiliary4 ∷
    ( HasThrow "err" Errors m,
      HasState "blocks" (Map.HashMap Name.Name BlockState) m,
      HasState "count" Word m,
      HasState "currentBlock" Name.Name m,
      HasState "typTab" TypeTable m,
      HasState "varTab" VariantToType m
    ) ⇒
    m Operand.Operand
mainPort = allocaNumPortsStatic False (Operand.ConstantOperand (C.Int 32 0))
auxiliary1 = allocaNumPortsStatic False (Operand.ConstantOperand (C.Int 32 1))
auxiliary2 = allocaNumPortsStatic False (Operand.ConstantOperand (C.Int 32 2))
auxiliary3 = allocaNumPortsStatic False (Operand.ConstantOperand (C.Int 32 3))
auxiliary4 = allocaNumPortsStatic False (Operand.ConstantOperand (C.Int 32 4))

--------------------------------------------------------------------------------
-- Accessor aliases
--------------------------------------------------------------------------------

getIsPrimaryEle ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m
  ) ⇒
  Operand.Operand →
  m Operand.Operand
getIsPrimaryEle bothPrimary =
  getElementPtr $
    Types.Minimal
      { Types.type' = Type.i1,
        Types.address' = bothPrimary,
        Types.indincies' = Block.constant32List [0, 0]
      }

loadIsPrimaryEle ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m
  ) ⇒
  Operand.Operand →
  m Operand.Operand
loadIsPrimaryEle e = getIsPrimaryEle e >>= load Type.i1

getPrimaryNode ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m
  ) ⇒
  Operand.Operand →
  m Operand.Operand
getPrimaryNode bothPrimary =
  getElementPtr $
    Types.Minimal
      { Types.type' = nodePointer,
        Types.address' = bothPrimary,
        Types.indincies' = Block.constant32List [0, 1]
      }

loadPrimaryNode ∷
  ( HasThrow "err" Errors m,
    HasState "blocks" (Map.HashMap Name.Name BlockState) m,
    HasState "count" Word m,
    HasState "currentBlock" Name.Name m
  ) ⇒
  Operand.Operand →
  m Operand.Operand
loadPrimaryNode e = getPrimaryNode e >>= load Type.i1
