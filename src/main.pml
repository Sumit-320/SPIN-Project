mtype = { insert_card, pin_entry, balance, withdrawal, amount, cash, more_yes, more_no, exit};
#define CORRECT_PIN 1234

chan user_to_atm = [0] of { mtype, int };   
chan atm_to_user = [0] of { mtype };        

int balance_amt = 100000; 
bool card_inserted = false;
bool transaction_done = false;
bool withdrawal_requested = false; 
bool cash_dispensed = false; 
int pin_attempts = 0;
bool session_ended = false;



proctype User() {
    bool session_active = true;
    int pin = 1234;      
    int choice = 2;     
    int amt = 200; 

    printf("\n===== Starting ATM Session =====\n");
    printf("User: Please insert your ATM-card\n");
    user_to_atm!insert_card, 0;

    printf("User: Entering PIN: %d\n", pin);
    user_to_atm!pin_entry, pin;

    mtype atm_response;
    atm_to_user?atm_response;

    if
    :: (atm_response == exit) ->
        printf("User: Session ended due to incorrect PIN.\n");
        session_active = false;
    :: else ->
        skip;
    fi;

    if
    :: (session_active && choice == 1) ->
        printf("User: Checking balance...\n");
        user_to_atm!balance, 0;
    :: (session_active && choice == 2) ->
        printf("User: Requesting withdrawal of %d\n", amt);
        user_to_atm!withdrawal, 0;
        user_to_atm!amount, amt;
    fi;

    if
    :: session_active ->
        printf("User: No more transactions.\n");
        user_to_atm!more_no, 0;
    fi;
}





proctype ATM() {
    int session_id = 6957;
    mtype action;
    int value;

    printf("\n===== ATM Session ID: %d =====\n", session_id);

    // waiting for card insrtion - IDLE State
    user_to_atm?action, value;
    if
    :: (action == insert_card) ->
        card_inserted = true;
        printf("ATM: Card inserted successfully\n");
    fi;

    // PIN checking 
    user_to_atm?action, value;
    if
    :: (action == pin_entry) ->
        printf("ATM: PIN entered: %d\n", value);

        if
            // Guard
        :: (value == CORRECT_PIN) ->
            // Command
	    pin_attempts++;
            printf("ATM: Correct PIN. Proceeding to transaction.\n");
            atm_to_user!balance; // dummy signal to continue
        :: else ->
            pin_attempts++;
            printf("ATM: Wrong PIN. Attempts: %d\n", pin_attempts);
            atm_to_user!exit;
                goto end;
        fi;
    fi;

    // transaction: (Balance check or withdrawal) -> I defined "1" for Balance Check and "2" for Withdrawal
    user_to_atm?action, value;
    if
    :: (action == balance) ->
        transaction_done = true;
        printf("ATM: Current balance: %d\n", balance_amt);
    :: (action == withdrawal) ->
        transaction_done = true;
        user_to_atm?action, value; 
        if
        :: (action == amount) ->
            if
            :: (value <= balance_amt) ->
                balance_amt = balance_amt - value;
		cash_dispensed = true; 

                printf("ATM: Dispensing cash: %d\n", value);
                printf("ATM: Remaining balance: %d\n", balance_amt);
            :: else ->
                printf("ATM: Insufficient funds. Requested: %d, Available: %d\n", value, balance_amt);
            fi;
        fi;
    fi;

    // Session End
    user_to_atm?action, value;
    if
    :: (action == more_no) ->
        printf("ATM: Session complete. Returning to IDLE.\n");
	session_ended = true;
    fi;

end:
    printf("ATM: Session ID %d terminated.\n", session_id);    
}

init {
    atomic {
        run ATM(); 
        run User(); 
    }
}


ltl transaction_complete {
    [](withdrawal_requested -> [] (cash_dispensed))
}


/* 
// Liveness poperty that eventually seassion ends in ATM and is not stuck infinitely creating a deadlock
ltl session_ended_flag {
    [](more_no -> <> session_ended)
}
*/ 

/*
// Liveness property ensuring cash is dispensed if withdrawal is requested or ATM ends session due to some reasons (eg: insufficient funds)
ltl transaction_complete {
    [](withdrawal_requested -> <> !(cash_dispensed || (atm_to_user == exit)))
}
*/
