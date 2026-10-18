class BankAccount {
  String bankName;
  String bankAccount;
  String bankHolder;

  BankAccount({
    this.bankName = '',
    this.bankAccount = '',
    this.bankHolder = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'bank_name': bankName,
      'bank_account': bankAccount,
      'bank_holder': bankHolder,
    };
  }

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      bankName: map['bank_name'] ?? '',
      bankAccount: map['bank_account'] ?? '',
      bankHolder: map['bank_holder'] ?? '',
    );
  }
}
