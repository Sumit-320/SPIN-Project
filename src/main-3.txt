mtype = { insert_card, pin_entry, balance, withdrawal, amount, cash, more_yes, more_no, exit };

chan user_to_atm = [0] of { mtype, int };
chan atm_to_user = [0] of { mtype };

#define CORRECT_PIN 1234

int withdrawal_amount = 0;
int balance_amt = 100;

bool card_inserted = false;
bool transaction_done = false;
bool withdrawal_requested = false; 
bool cash_dispensed = false;
int pin_attempts = 0;

proctype User() {
    bool session_active = true;
    int pin = 12345;     
    int choice = 2;
    int amt = 200;

    printf("\n===== Starting ATM Session =====\n");
    printf("User: Insert card\n");
    user_to_atm!insert_card, 0;

    printf("User: Entering PIN: %d\n", pin);
    user_to_atm!pin_entry, pin;

    mtype atm_response;
    atm_to_user?atm_response;

    if
    :: (atm_response == exit) -> 
        printf("User: Session ended due to incorrect PIN.\n");
        goto end_session;
    :: else -> skip;
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

end_session:
    printf("User: Exiting due to error or session end.\n");
}

proctype ATM() {
    int session_id = 101;
    mtype action;
    int value;

    printf("\n===== ATM Session ID: %d =====\n", session_id);

    user_to_atm?action, value;
    if
    :: (action == insert_card) -> 
        card_inserted = true;
        printf("ATM: Card inserted.\n");
    fi;

    user_to_atm?action, value;
    if
    :: (action == pin_entry) -> 
        printf("ATM: PIN entered: %d\n", value);
        if
        :: (value == CORRECT_PIN) -> 
            printf("ATM: Correct PIN. Proceeding to transaction.\n");
            atm_to_user!balance;
        :: else -> 
            pin_attempts++;
            atm_to_user!exit;
            printf("ATM: Wrong PIN. Attempts: %d\n", pin_attempts);
            goto terminate;
        fi;
    fi;

    user_to_atm?action, value;
    if
    :: (action == balance) -> 
        transaction_done = true;
        printf("ATM: Current balance: %d\n", balance_amt);
        atm_to_user!more_yes;

    :: (action == withdrawal) -> 
        withdrawal_requested = true;
        user_to_atm?action, value;
        if
        :: (action == amount) -> 
            withdrawal_amount = value;
            if
            :: (value <= balance_amt) -> 
                balance_amt = balance_amt - value;
                printf("ATM: Dispensing cash: %d\n", value);
                printf("ATM: Remaining balance: %d\n", balance_amt);
                cash_dispensed = true;
                atm_to_user!cash;
            :: else -> 
                printf("ATM: Insufficient funds. Requested: %d, Available: %d\n", value, balance_amt);
                goto terminate;
            fi;
        fi;
    fi;

    user_to_atm?action, value;
    if
    :: (action == more_no) -> 
        printf("ATM: Session complete. Returning to IDLE.\n");
    fi;

terminate:
    printf("ATM: Session ID %d terminated.\n", session_id);
}

init {
    atomic {
        run ATM();
        run User();
    }
}

ltl no_cash_on_insufficient_funds {
    []( (withdrawal_requested && (withdrawal_amount > balance_amt)) -> !cash_dispensed )
}
