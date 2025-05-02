mtype = { insert_card, pin_entry, balance, withdrawal, amount, cash, more_yes, more_no, exit };

chan user_to_atm = [0] of { mtype, int };   
chan atm_to_user = [0] of { mtype };         
#define CORRECT_PIN 1234
int withdrawal_amount = 0;
int balance_amt = 100; // Initial balance

bool card_inserted = false;
bool transaction_done = false;
bool withdrawal_requested = false; 
bool cash_dispensed = false;

proctype User() {
    int pin_attempts = 0;
    bool session_active = true;
    int pin = 1234;     
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
    int session_id = 101;
    int pin_attempts = 0;
    mtype action;
    int value;

    printf("\n===== ATM Session ID: %d =====\n", session_id);

    // Step 1: Wait for insert_card
    user_to_atm?action, value;
    if
    :: (action == insert_card) -> 
        card_inserted = true;
        printf("ATM: Card inserted.\n");
    fi;

    // Step 2: PIN check
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
            printf("ATM: Wrong PIN. Attempts: %d\n", pin_attempts);
            if
            :: (pin_attempts >= 3) -> 
                printf("ATM: Too many wrong attempts. Exiting.\n");
                atm_to_user!exit;
                goto wait_for_exit;
            :: else -> 
                atm_to_user!exit;
                goto wait_for_exit;
            fi;
        fi;
    fi;

    // Step 3: Transaction
    user_to_atm?action, value;
    if
    :: (action == balance) -> 
        transaction_done = true;
        printf("ATM: Current balance: %d\n", balance_amt);
        atm_to_user!more_yes;

    :: (action == withdrawal) -> 
        withdrawal_requested = true;
        user_to_atm?action, value; // Get amount
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
                //atm_to_user!exit; // Optional exit due to insufficient funds
                goto wait_for_exit;
            fi;
        fi;
    fi;

    // Step 4: End session
    user_to_atm?action, value;
    if
    :: (action == more_no) -> 
        printf("ATM: Session complete. Returning to IDLE.\n");
    fi;

wait_for_exit:
    user_to_atm?action, value;
    if
    :: (action == more_no) -> 
        printf("ATM: Session complete after exit.\n");
    fi;

    printf("ATM: Session ID %d terminated.\n", session_id);
}

init {
    atomic {
        run ATM();
        run User();
    }
}

// Safety Property to ensure if withdrawel amount > balance amount --> cash is not dispensed
ltl no_cash_on_insufficient_funds {
    []( (withdrawal_requested && (withdrawal_amount > balance_amt)) -> !cash_dispensed )
}
