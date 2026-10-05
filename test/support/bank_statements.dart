// Synthetic exports: no real account or customer data.
const bankStatements = <String, String>{
  'abn_amro':
      '123456789\tEUR\t20261004\t2000,00\t765,44\t20261004\t-1234,56\t/TRTP/SEPA OVERBOEKING/IBAN/NL00TEST0000000001/BIC/TESTNL2A/NAME/Café Example/REMI/Invoice 42\n'
      '123456789\tEUR\t20261005\t765,44\t3265,44\t20261005\t2500,00\tSEPA Overboeking IBAN: NL00TEST0000000002 BIC: TESTNL2A Naam: Example Employer Omschrijving: Salary\n',
  'rabobank':
      'IBAN/BBAN,Munt,BIC,Volgnr,Datum,Rentedatum,Bedrag,Saldo na trn,Tegenrekening IBAN/BBAN,Naam tegenpartij,Naam uiteindelijke partij,Naam initiërende partij,BIC tegenpartij,Code,Batch ID,Transactiereferentie,Machtigingskenmerk,Incassant ID,Betalingskenmerk,Omschrijving-1,Omschrijving-2,Omschrijving-3,Reden retour,Oorspr bedrag,Oorspr munt,Koers\n'
      'NL00TEST0000000000,EUR,TESTNL2A,1,2026-10-04,2026-10-04,"-1.234,56","765,44",NL00TEST0000000001,Café Example,,,TESTNL2A,ei,,,,,,Invoice 42,"Part two, details",Part three,,,,\n'
      'NL00TEST0000000000,EUR,TESTNL2A,2,2026-10-05,2026-10-05,"2500,00","3265,44",NL00TEST0000000002,Example Employer,,,TESTNL2A,cb,,,,,,Salary,,,,,,\n',
  'bunq':
      'Date;Interest Date;Amount;Account;Counterparty;Name;Description\n'
      '2026-10-04;2026-10-04;1234,56-;NL00TEST0000000000;NL00TEST0000000001;Café Example;"Invoice 42; line one\nline two with ""quotes"""\n'
      '2026-10-05;2026-10-05;2500,00;NL00TEST0000000000;NL00TEST0000000002;Example Employer;Salary\n',
  'sns':
      'Datum,Je rekening,Van / naar,Naam,Valuta saldo,Saldo voor boeking,Valuta boeking,Bedrag bij/af,Verwerkingsdatum,Valutadatum,Code,Type,Volgnummer,Betalingskenmerk,Omschrijving,Afschriftnummer,Categorie\n'
      '4-10-2026,NL00TEST0000000000,NL00TEST0000000001,Café Example,EUR,2000.00,EUR,-1234.56,4-10-2026,4-10-2026,9820,BEA,1,REF42,Invoice 42,1,Groceries\n'
      '5-10-2026,NL00TEST0000000000,NL00TEST0000000002,Example Employer,EUR,765.44,EUR,2500.00,5-10-2026,5-10-2026,8810,NGM,2,,Salary,1,\n',
  'knab':
      'KNAB EXPORT;;;;;;;;;;;;;;\n'
      'Rekeningnummer;Transactiedatum;Valutacode;CreditDebet;Bedrag;Tegenrekeningnummer;Tegenrekeninghouder;Valutadatum;Betaalwijze;Omschrijving;Type betaling;Machtigingsnummer;Incassant ID;Adres;\n'
      '"NL00TEST0000000000";"04-10-2026";"EUR";"D";"1234,56";"NL00TEST0000000001";"Café Example";"04-10-2026";"Overboeking";"Invoice 42";"";"";"";"";\n'
      '"NL00TEST0000000000";"05-10-2026";"EUR";"C";"2500,00";"NL00TEST0000000002";"Example Employer";"05-10-2026";"Ontvangen betaling";"Salary";"";"";"";"";\n',
};
