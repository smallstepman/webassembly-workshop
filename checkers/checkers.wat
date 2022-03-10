(module
  (import "events" "piecemoved"
    (func $notify_piecemoved (param $fromX i32) (param $fromY i32)
                           (param $toX i32) (param $toY i32)))
  (import "events" "piececrowned"
    (func $notify_piececrowned (param $pieceX i32) (param $pieceY i32)))

  (memory $mem 1)
  (global $WHITE i32 (i32.const 2))
  (global $BLACK i32 (i32.const 1))
  (global $CROWN i32 (i32.const 4))
  (global $currentTurn (mut i32) (i32.const 0))
  


  (func $indexForPosition (param $x i32) (param $y i32) (result i32)
    (i32.add
      (i32.mul
        (i32.const 8)
        (get_local $y)  
      )  
      (get_local $x)
    )      
  )
  ;; offset = ( x + y * 8 ) * 8
  (func $offsetForPosition (param $x i32) (param $y i32) (result i32)
    (i32.mul
      (call $indexForPosition (get_local $x) (get_local $y))
      (i32.const 4)  
    )
  )
  ;; determine if a piece has been crowned
  (func $isCrowned (param $piece i32) (result i32)
    (i32.eq
      (i32.and (get_local $piece) (get_global $CROWN))
      (get_global $CROWN)  
    )      
  )
  ;; determine if a piece is white
  (func $isWhite (param $piece i32) (result i32)
    (i32.eq
      (i32.and (get_local $piece) (get_global $WHITE))
      (get_global $WHITE)
    )      
  )
  ;; determine if a piece is white
  (func $isBlack (param $piece i32) (result i32)
    (i32.eq
      (i32.and (get_local $piece) (get_global $BLACK))
      (get_global $BLACK)
    )      
  )
  ;; adds a crown to a given piece (no mutation)
  (func $withCrown (param $piece i32) (result i32)
    (i32.or (get_local $piece) (get_global $CROWN))      
  )
  ;; removes a crown from a given piece (no mutation )
  (func $withoutCrown (param $piece i32) (result i32)
    (i32.or (get_local $piece) (i32.const 3))      
  )
  ;; sets a piece on the board
  (func $setPiece (param $x i32) (param $y i32) (param $piece i32)
    (i32.store 
      (call $offsetForPosition
        (get_local $x)
        (get_local $y)  
      )  
      (get_local $piece)
    )      
  )
  ;; gets a piece from the board. out of range causes a trap
  (func $getPiece (param $x i32) (param $y i32) (result i32)
    (if (result i32)
      (block (result i32)
        (i32.and
          (call $inRange
            (i32.const 0)
            (i32.const 7)
            (get_local $x)
          )  
          (call $inRange
            (i32.const 0)
            (i32.const 7)
            (get_local $y)    
          )
        )
      )
    (then 
      (i32.load
        (call $offsetForPosition
          (get_local $x)
          (get_local $y)
        )
      )  
    )
    (else
      (unreachable)  
    )  
   )      
  )
  ;; detect if values are within range (inclusive high and low)
  (func $inRange (param $low i32) (param $high i32) (param $value i32) (result i32)
    (i32.and
      (i32.ge_s (get_local $value) (get_local $low))
      (i32.le_s (get_local $value) (get_local $high)) 
    )      
  )
  ;; gets the current turn owner (white or black)
  (func $getTurnOwner (result i32)
    (get_global $currentTurn)      
  )
  ;; at the end of a turn, switch turn owner to the other player
  (func $toggleTurnOwner
    (if (i32.eq (call $getTurnOwner) (i32.const 1))
      (then (call $setTurnOwner (i32.const 2)))
      (else (call $setTurnOwner (i32.const 1)))  
    )      
  )
  ;; sets the turn owner 
  (func $setTurnOwner (param $piece i32)
    (set_global $currentTurn (get_local $piece))      
  )
  ;; determine if it's a player's turn
  (func $isPlayerTurn (param $player i32) (result i32)
    (i32.gt_s
      (i32.and (get_local $player) (call $getTurnOwner))
      (i32.const 0)  
    )      
  )
  ;; let's crown black pieces in row 0 and white pieces in row 7
  (func $shouldCrown (param $pieceY i32) (param $piece i32) (result i32)
    (i32.or
      (i32.and
        (i32.eq
          (get_local $pieceY)
          (i32.const 0)  
        )
        (call $isBlack (get_local $piece))  
      )
      (i32.and
        (i32.eq
          (get_local $pieceY)
          (i32.const 7)  
        )
        (call $isWhite (get_local $piece))  
      )  
    )      
  )
  ;; converts a piece onto a crowned piece and invokes a host notifier
  (func $crownPiece (param $x i32) (param $y i32)
    (local $piece i32)
    (set_local $piece (call $getPiece (get_local $x)(get_local $y)))

    (call $setPiece (get_local $x) (get_local $y)
      (call $withCrown (get_local $piece)))

    (call $notify_piececrowned (get_local $x)(get_local $y))    
  )
  ;; distance
  (func $distance (param $x i32)(param $y i32)(result i32)
    (i32.sub (get_local $x) (get_local $y))      
  )
  ;; determine if the move is valid
  (func $isValidMove (param $fromX i32) (param $fromY i32)
                     (param $toX i32) (param $toY i32) (result i32)
    (local $player i32)
    (local $target i32)

    (set_local $player (call $getPiece (get_local $fromX) (get_local $fromY)))
    (set_local $target (call $getPiece (get_local $toX) (get_local $toY)))

    (if (result i32)
      (block (result i32)
        (i32.and
          (call $validJumpDistance (get_local $fromY) (get_local $toY))
          (i32.and
            (call $isPlayerTurn (get_local $player))
            (i32.eq (get_local $target) (i32.const 0)) ;; target must be unoccupied  
          )  
        )
      )
      (then
        (i32.const 1)  
      )
      (else
        (i32.const 0)  
      )
    )     
  )
  ;; ensures travel is 1 or 2 squaries
  (func $validJumpDistance (param $from i32) (param $to i32) (result i32)
    (local $d i32)
    (set_local $d
      (if (result i32)
        (i32.gt_s (get_local $to) (get_local $from))
        (then 
          (call $distance (get_local $to) (get_local $from))  
        )  
        (else
          (call $distance (get_local $from) (get_local $to))  
        )
      )
    )
    (i32.le_u
      (get_local $d)
      (i32.const 2)  
    )
  )
  ;; exported move function to be called by the game host
  (func $move (param $fromX i32) (param $fromY i32)
              (param $toX i32) (param $toY i32) (result i32)
    (if (result i32)
      (block (result i32)
        (call $isValidMove (get_local $fromX) (get_local $fromY)
                           (get_local $toX) (get_local $toY))       
      )
      (then 
        (call $do_move (get_local $fromX) (get_local $fromY)
                       (get_local $toX) (get_local $toY))  
      )
      (else
        (i32.const 0)  
      )  
    )     
  )
  ;; internal move function, performs actual move post validation of target. 
  ;; currently not handled
  ;;   removiing opponent piece during jump
  ;;   detecting win condition
  (func $do_move (param $fromX i32) (param $fromY i32)
                 (param $toX i32) (param $toY i32) (result i32)
    (local $curpiece i32)
    (set_local $curpiece (call $getPiece (get_local $fromX)(get_local $fromY)))

    (call $toggleTurnOwner)
    (call $setPiece (get_local $toX) (get_local $toY) (get_local $curpiece))
    (call $setPiece (get_local $fromX) (get_local $fromY) (i32.const 0))
    (if (call $shouldCrown (get_local $toY) (get_local $curpiece))
      (then (call $crownPiece (get_local $toX) (get_local $toY)))  )
    (call $notify_piecemoved (get_local $fromX) (get_local $fromY) 
                             (get_local $toX) (get_local $toY) )
    (i32.const 1)
  )
  ;; Manually place each piece on the board to initialize the game
  (func $initBoard
  ;; Place the white pieces at the top of the board
    (call $setPiece (i32.const 1) (i32.const 0) (i32.const 2))
    (call $setPiece (i32.const 3) (i32.const 0) (i32.const 2))
    (call $setPiece (i32.const 5) (i32.const 0) (i32.const 2))
    (call $setPiece (i32.const 7) (i32.const 0) (i32.const 2))
    (call $setPiece (i32.const 0) (i32.const 1) (i32.const 2))
    (call $setPiece (i32.const 2) (i32.const 1) (i32.const 2))
    (call $setPiece (i32.const 4) (i32.const 1) (i32.const 2))
    (call $setPiece (i32.const 6) (i32.const 1) (i32.const 2))
    (call $setPiece (i32.const 1) (i32.const 2) (i32.const 2))
    (call $setPiece (i32.const 3) (i32.const 2) (i32.const 2))
    (call $setPiece (i32.const 5) (i32.const 2) (i32.const 2))
    (call $setPiece (i32.const 7) (i32.const 2) (i32.const 2))

    (call $setPiece (i32.const 0) (i32.const 7) (i32.const 1))
    (call $setPiece (i32.const 2) (i32.const 7) (i32.const 1))
    (call $setPiece (i32.const 4) (i32.const 7) (i32.const 1))
    (call $setPiece (i32.const 6) (i32.const 7) (i32.const 1))
    (call $setPiece (i32.const 1) (i32.const 6) (i32.const 1))
    (call $setPiece (i32.const 3) (i32.const 6) (i32.const 1))
    (call $setPiece (i32.const 5) (i32.const 6) (i32.const 1))
    (call $setPiece (i32.const 7) (i32.const 6) (i32.const 1))
    (call $setPiece (i32.const 0) (i32.const 5) (i32.const 1))
    (call $setPiece (i32.const 2) (i32.const 5) (i32.const 1))
    (call $setPiece (i32.const 4) (i32.const 5) (i32.const 1))
    (call $setPiece (i32.const 6) (i32.const 5) (i32.const 1))
    (call $setTurnOwner (i32.const 1)) ;; Black goes first
  )
  ;;
  (export "offsetForPosition" (func $offsetForPosition))
  (export "isCrowned" (func $isCrowned))
  (export "isBlack" (func $isBlack))
  (export "isWhite" (func $isWhite))
  (export "withCrown" (func $withCrown))
  (export "withoutCrown" (func $withoutCrown))
  (export "getPiece" (func $getPiece))
  (export "initBoard" (func $initBoard))
  (export "getTurnOwner" (func $getTurnOwner))
  (export "move" (func $move))
  (export "memory" (memory $mem))

)
