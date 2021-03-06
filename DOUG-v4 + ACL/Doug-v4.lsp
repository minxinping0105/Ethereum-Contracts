;Doug-v4
;
;Default Behaviour: If a name has not been registered before, Automatically accept
;					If "ACL" has not been registered yet, Automatically accept

;Usage:				 

;API
;Check Name 	- Permission needed: 0
; 				- Form: "check" "Name"
;				- Returns: 0 (DNE), 0xContractAddress

;Get DB Size 	- Permission needed: 0
;				- Form: "dbsize"
;				- Returns: # of entries

;Data Dump 		- Permission needed: 0
;				- Form: "dump"
;				- Returns: list["Name":0xContractAddress]

;In list? 	 	- Permission needed: 0
; (Known names)	- Form: "known" "Name"
;				- Returns: 1 (Is Known), 0 (Not)

;Register Name 	- Permission needed: 1
;				- Form: "register" "Name" <0xTargetAddress>
;				- Returns: 1 (Success), 0 (Failure)

;Structure
;=========

;Names List
;----------
;The Names list is implemented as a linked list for future proofability
;At some point in the future it might be desirable to be able to edit 
;And store some data tied to a contract name. This is not currently used
;But would be easy to add in slots "name"+i>2. This linked list is
;Bi-Directional in order to future proof incase deletions are someday 
;wanted.
; 
;@@"name" 0xContractAddress
;+1 "previous name"
;+2 "next name"

;Name History
;------------
;This version of Doug will store a history of every contract which has
;Been registered to Doug for each nameover the course of his existance.
;It is implemented as a uni-directional linked list starting at "name"
;
;@0xContractforname 0xPreviouscontractforname

{
	;METADATA SECTION
	[[0x0]] 0x88554646AB						;metadata notifier
	[[0x1]] (CALLER)							;contract creator
	[[0x2]] "Dennis McKinnon"					;contract Author
	[[0x3]] 0x013052014							;Date
	[[0x4]] 0x001005000							;version XXX.XXX.XXX
	[[0x5]] "doug" 								;Name
	[[0x6]] "12345678901234567890123456789012"	;Brief description (not past address 0xF)
	[[0x6]] "Doug is a Decentralized Organiza"
	[[0x7]] "tion Upgrade Guy. His purpose is"
	[[0x8]] "to serve a recursive register fo"
	[[0x9]] "r contracts belonging to a DAO s"
	[[0xA]] "other contracts can find out whi"
	[[0xB]] "ch addresses to reference withou"
	[[0xC]] "hardcoding. It also allows any c"
	[[0xD]] "contract to be swapped out inclu"
	[[0xE]] "ding DOUG himself."

	;INITIALIZATION
	[[0x10]] 0x11d11764cd7f6ecda172e0b72370e6ea7f75f290 ;NameReg address
	[[0x11]] 1  			; Number of registered names

	;Name Linked list
	[[0x15]] 0x17 ; Set tail
	[[0x16]] "doug" ;	Set head

	[[0x19]]"doug"	    	; Add doug as first in name list (for consistancy) 
	[["doug"]](ADDRESS)		; Register doug with doug
	[[(+ "doug" 1)]]0x17 	; Set previous to tail

;	NAME REGISTRATION
;	[0x0]"Doug - Revolution"
;	(call (- (GAS) 100) @@0x10 0 0x0 0x11 0 0) ;Register the name DOUG

}
{
;-----------------------------------------------------
;Check Name 	- Permission needed: 0
; 				- Form: "check" "Name"
;				- Returns: 0 (DNE), 0xContractAddress
;Get the Contract Address currently associated with "name"

	[0x0](calldataload 0) ;Get command
	(when (= @0x0 "check")
		{
			[0x20]@@(calldataload 0x20) ;Get address associated with "name"
			(return 0x20 0x20) ; Return the Address
		}
	)

;--------------------------------------
;Get DB Size 	- Permission needed: 0
;				- Form: "dbsize"
;				- Returns: # of entries

	(when (= @0x0 "dbsize")
		{
			[0x20]@@0x11 	;Fetch the list size from storage (slot 0x11)
			(return 0x20 0x20) 	;Return the result
		}
	)

;--------------------------------------------------------
;Data Dump 		- Permission needed: 0
;				- Form: "dump"
;				- Returns: list["Name":0xContractAddress]
	
	(when (= @0x0 "dump")
		{
			;Start at Tail
			[0x20] @@(+ @@0x15 2)
			[0x40]0x100
			(while @0x20 ;Loop until end is found
				{
					;
					[@0x40]@0x20 				; @0x20 is "name"
					[(+ @0x40 0x20)]@@ @0x20 	; @@ @0x20 is contract address
					[0x20]@@(+ @0x20 2)			; "name"+2 is pointer to next name in list (0 if at end)
					[0x40](+ @0x40 0x40)		; Increment memory pointer
				}
			)
			;All Stored in memory now return it
			(return 0x100 (- @0x40 0x100))
		}
	)

;-----------------------------------------------
;In list? 	 	- Permission needed: 0
; (Known names)	- Form: "known" "Name"
;				- Returns: 1 (Is Known), 0 (Not)
;This is a largely unecessary function which
;returns 1 id a name is in the registered list
;and 0 otherwise

	(when (= @0x0 "known")
		{
			[0x20](calldataload 0x20) ;Get "name"
			[0x40]0
			(when @@ @0x20 [0x40]1) ;When there is a Contract listed at Name
			(return 0x40 0x20)	;Return result
		}
	)

;-----------------------------------------------------------
;Register Name 	- Permission needed: 1
;				- Form: "register" "Name" <0xTargetAddress>
;				- Returns: 1 (Success), 0 (Failure)

	(when (= @0x0 "register")
		{
			[0x20] (calldataload 0x20) 		; Get "name"
			[0x40] (calldataload 0x40)		; Get Target address
			(unless @0x40 [0x40](CALLER))	; If Target address not provided Default: (CALLER)

			(unless (&& (> @0x20 0x20)(> @0x40 0x20)) (STOP)); Prevent out of bounds registrations

			[0x60] 0 	;where permission will be stored (cleared out just to be safe)
			(if (&& @@"ACL" @@ @0x20) ;If ACL is registered AND the name is taken
				{
					;If ACL is registered -> Use it to get permissions of caller
					[0x80]"check"
					[0xA0](CALLER) 
					(call (- (GAS) 100) @@"ACL" 0 0x80 0x40 0x60 0x20)
				}
				{
					;If ACL is not registered -> Automatic Permission of 1
					[0x60]1
				}
			)

			(unless @0x60 (STOP)) ;If permissions are not 1 then stop

			
			(if (= @@ @0x20 0) ;name does not exist yet
				{
					;Perform appending to list (check that there is space)
					(unless (&& (= @@(- @0x20 2) 0) (= @@(- @0x20 1) 0) (= @@(+ @0x20 1) 0) (= @@(+ @0x20 2) 0) (= @@ @0x40 0)) (STOP)) ; Check enough space 
					[[@0x20]] @0x40 ;Store target at name
					[[(+ @0x20 1)]] @@0x16 	;Set previous to value in head
					[[(+ @@0x16 2)]] @0x20 	;Set head's next to current name
					[[0x16]]@0x20 			;Set Head to current name
				}
				{
					;Don't append but push name history down
					(unless (= @@ @0x40 0) (STOP)) ;Ensure writing to target won't overwrite anything
					[[@0x40]] @@ @0x20 	;Copy previous contract to pointer of new contract
					[[@0x20]] @0x40 	;Register target to name
				}
			)
			[0xC0]1
			(return 0xC0 0x20)
		}
	)

}

