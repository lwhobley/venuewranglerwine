# Importing operational data

Open **Home → Import data**, select a record type, then choose a file or paste text. Correct extracted text, map the columns, and review every validation error before confirming the destination organization and venue. CSV headers can be copied or saved from the importer.

Supported sources: CSV, TSV, pasted tables or `field: value` forms, Excel `.xlsx`, text PDFs, and JPG/PNG/WebP photos. Android and iOS use on-device OCR for photos and scanned PDFs. Excel worksheets and PDF pages are selected and imported separately. Legacy `.xls` files must be saved as `.xlsx`; spreadsheet formulas must be replaced with values. Date/time fields need ISO timestamps with a UTC offset or `Z`.

Limits: 20 MB per uploaded file, 40 PDF pages, 2 MB of extracted text, and 500 rows per import. OCR and document layouts can require manual corrections; extracted data is editable and is not saved until confirmed.

| Records | Import key / dependencies |
| --- | --- |
| Inventory catalog; wine profiles | Organization SKU |
| Locations / concourses / outlets / rooms / zones | Venue code; optional parent code |
| Racks and addressable bins | Room code + rack code; existing rack template |
| Suppliers | Organization supplier name |
| Stock receipts | Venue source ID; existing SKU and supplier; optional destination bin |
| Floor tables | Venue table label |
| Guests | Venue source ID |
| Reservations | Venue source ID; imported guest source ID |
| Club members | Organization source ID |
| Events; staff shifts | Venue source ID |
| Checklists | Venue checklist name + item label |
| Documents / procedures | Venue source ID |
| Wine lists / menus | Venue name + list type |
| Wine list items | Venue list name + type + SKU |

Each dataset requires its existing write permission. Unchanged rows are skipped. Metadata can be updated using the same key. Receipts, reservations, events, and shifts reject changed data for an existing source ID; use a new ID for a new transaction. Stock receipts use the existing inventory ledger. A failing row rolls back the complete batch.

The backend integration test in `supabase/tests/data_ingestion_test.sql` creates temporary fixtures, tests all 16 datasets and authorization, and rolls back all test writes. Run it only against the matching wine schema through the Supabase connector.
