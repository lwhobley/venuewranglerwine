import '../../../core/permissions/permission.dart';

enum ImportValueType { text, code, integer, decimal, boolean, timestamp, email }

class ImportField {
  const ImportField(
    this.key,
    this.label, {
    this.required = false,
    this.type = ImportValueType.text,
    this.defaultValue = '',
    this.choices = const [],
    this.aliases = const [],
    this.min,
    this.max,
  });
  final String key;
  final String label;
  final bool required;
  final ImportValueType type;
  final String defaultValue;
  final List<String> choices;
  final List<String> aliases;
  final int? min;
  final int? max;
}

class ImportSchema {
  const ImportSchema(
    this.key,
    this.label,
    this.permission,
    this.fields,
    this.keyFields, {
    this.help = 'Existing records with the same key are updated. Unchanged rows are skipped.',
  });
  final String key;
  final String label;
  final String permission;
  final List<ImportField> fields;
  final List<String> keyFields;
  final String help;
}

const _requiredId = ImportField(
  'external_id',
  'Source ID',
  required: true,
  aliases: ['id', 'reference', 'record_id'],
);
const _name = ImportField(
  'name',
  'Name',
  required: true,
  min: 2,
  max: 80,
  aliases: ['display_name', 'title'],
);
const _code = ImportField(
  'code',
  'Code',
  required: true,
  type: ImportValueType.code,
  max: 24,
);
const _sku = ImportField(
  'sku',
  'SKU',
  required: true,
  type: ImportValueType.code,
  min: 2,
  max: 32,
  aliases: ['product_code', 'item_code', 'stock_code'],
);
const _cost = ImportField(
  'unit_cost',
  'Unit cost',
  type: ImportValueType.decimal,
  defaultValue: '0',
  aliases: ['cost', 'price', 'unit_price'],
);
const _starts = ImportField(
  'starts_at',
  'Starts at',
  required: true,
  type: ImportValueType.timestamp,
  aliases: ['start', 'start_time', 'date_time'],
);

const importSchemas = <ImportSchema>[
  ImportSchema(
    'inventory',
    'Inventory catalog',
    Permission.wineCatalogWrite,
    [
      _sku,
      _name,
      _cost,
      ImportField('barcode', 'Barcode'),
      ImportField(
        'status',
        'Status',
        defaultValue: 'active',
        choices: [
          'active',
          'seasonal',
          'archived',
          'discontinued',
          'unavailable',
          'on_order',
        ],
      ),
    ],
    ['sku'],
    help: 'Imports item details. Use Wine profiles for wine attributes and Stock receipts for quantities.',
  ),
  ImportSchema(
    'wines',
    'Wine profiles',
    Permission.wineCatalogWrite,
    [
      _sku,
      ImportField(
        'producer',
        'Producer',
        required: true,
        min: 2,
        aliases: ['winery', 'brand'],
      ),
      ImportField(
        'cuvee',
        'Cuvee',
        required: true,
        aliases: ['wine', 'wine_name', 'product', 'name'],
      ),
      ImportField(
        'wine_type',
        'Wine type',
        required: true,
        choices: [
          'red',
          'white',
          'rose',
          'sparkling',
          'champagne',
          'orange',
          'dessert',
          'fortified',
          'sake',
          'non_alcoholic',
        ],
        aliases: ['type', 'style'],
      ),
      ImportField('vintage', 'Vintage', defaultValue: 'NV', aliases: ['year']),
      ImportField(
        'bottle_ml',
        'Bottle size (ml)',
        required: true,
        type: ImportValueType.integer,
        min: 1,
        aliases: ['size_ml', 'volume_ml'],
      ),
      _cost,
      ImportField('country', 'Country'),
      ImportField('region', 'Region'),
    ],
    ['sku'],
  ),
  ImportSchema(
    'locations',
    'Locations & concourses',
    Permission.wineCatalogWrite,
    [
      _code,
      _name,
      ImportField(
        'kind',
        'Location type',
        required: true,
        choices: ['concourse', 'outlet', 'room', 'zone'],
        aliases: ['type', 'location_type'],
      ),
      ImportField(
        'parent_code',
        'Parent location code',
        type: ImportValueType.code,
        max: 24,
        aliases: ['parent', 'concourse_code'],
      ),
      ImportField(
        'capacity_bottles',
        'Capacity',
        type: ImportValueType.integer,
        min: 1,
        aliases: ['capacity'],
      ),
    ],
    ['code'],
    help: 'Use parent codes to build concourse → outlet → room or zone hierarchies. Parent rows can appear anywhere in the file.',
  ),
  ImportSchema(
    'racks',
    'Racks & bins',
    Permission.wineCatalogWrite,
    [
      ImportField(
        'location_code',
        'Room code',
        required: true,
        type: ImportValueType.code,
        aliases: ['room_code'],
      ),
      _code,
      _name,
      ImportField(
        'template_key',
        'Rack template',
        required: true,
        aliases: ['template'],
      ),
    ],
    ['location_code', 'code'],
    help: 'Creates addressable bins using the selected rack template. Existing rack geometry is preserved.',
  ),
  ImportSchema(
    'suppliers',
    'Suppliers',
    Permission.wineReceive,
    [
      _name,
      ImportField(
        'email',
        'Contact email',
        type: ImportValueType.email,
        aliases: ['contact_email'],
      ),
      ImportField(
        'lead_time_days',
        'Lead time (days)',
        type: ImportValueType.integer,
        min: 0,
      ),
    ],
    ['name'],
  ),
  ImportSchema(
    'stock',
    'Stock receipts',
    Permission.wineReceive,
    [
      _requiredId,
      _sku,
      ImportField(
        'supplier',
        'Supplier name',
        required: true,
        aliases: ['vendor', 'supplier_name'],
      ),
      ImportField(
        'quantity',
        'Quantity',
        required: true,
        type: ImportValueType.integer,
        min: 1,
        aliases: ['qty', 'units', 'bottles'],
      ),
      _cost,
      ImportField(
        'slot_code',
        'Destination bin (optional)',
        aliases: ['bin', 'bin_code'],
      ),
    ],
    ['external_id'],
    help: 'Adds stock through an audited receipt. Empty destination means staging. Repeating a source ID never adds stock twice; changed receipts must use a new ID.',
  ),
  ImportSchema(
    'tables',
    'Floor tables',
    Permission.floorDesign,
    [
      ImportField(
        'label',
        'Table label',
        required: true,
        aliases: ['name', 'table', 'table_number'],
      ),
      ImportField(
        'capacity',
        'Seats',
        required: true,
        type: ImportValueType.integer,
        min: 1,
        max: 20,
        aliases: ['seats'],
      ),
    ],
    ['label'],
  ),
  ImportSchema(
    'guests',
    'Guest profiles',
    Permission.guestWrite,
    [
      _requiredId,
      _name,
      ImportField('allergies', 'Allergies'),
      ImportField(
        'seating',
        'Seating preference',
        aliases: ['seating_preference'],
      ),
      ImportField(
        'vip',
        'VIP',
        type: ImportValueType.boolean,
        defaultValue: 'false',
      ),
    ],
    ['external_id'],
  ),
  ImportSchema(
    'reservations',
    'Reservations',
    Permission.reservationWrite,
    [
      _requiredId,
      ImportField(
        'guest_external_id',
        'Imported guest source ID',
        required: true,
        aliases: ['guest_id'],
      ),
      ImportField(
        'party_size',
        'Party size',
        required: true,
        type: ImportValueType.integer,
        min: 1,
        max: 20,
        aliases: ['guests', 'covers'],
      ),
      ImportField(
        'reserved_at',
        'Reservation time',
        required: true,
        type: ImportValueType.timestamp,
        aliases: ['date_time', 'reservation_time'],
      ),
      ImportField('notes', 'Notes'),
    ],
    ['external_id'],
    help: 'Import guest profiles first. Times must include a UTC offset or Z. Existing reservations are preserved; changed bookings need a new source ID.',
  ),
  ImportSchema(
    'members',
    'Club members',
    Permission.wineAllocationManage,
    [
      _requiredId,
      _name,
      ImportField(
        'tier',
        'Tier',
        defaultValue: 'standard',
        choices: ['standard', 'reserve', 'founding'],
      ),
    ],
    ['external_id'],
  ),
  ImportSchema(
    'events',
    'Events',
    Permission.eventManage,
    [
      _requiredId,
      _name,
      ImportField(
        'guest_count',
        'Guest count',
        required: true,
        type: ImportValueType.integer,
        min: 1,
        aliases: ['guests', 'covers'],
      ),
      _starts,
    ],
    ['external_id'],
    help: 'Imports draft event inquiries. Times must include a UTC offset or Z. Repeated source IDs are skipped; changed events need a new source ID.',
  ),
  ImportSchema(
    'shifts',
    'Staff shifts',
    Permission.schedulePublish,
    [
      _requiredId,
      ImportField('role_key', 'Role', required: true, aliases: ['role']),
      _starts,
      ImportField(
        'ends_at',
        'Ends at',
        required: true,
        type: ImportValueType.timestamp,
        aliases: ['end', 'end_time'],
      ),
    ],
    ['external_id'],
    help: 'Imports unpublished shifts. Times must include a UTC offset or Z. Repeated source IDs are skipped; changed shifts need a new source ID.',
  ),
  ImportSchema(
    'checklists',
    'Checklists',
    Permission.checklistManage,
    [
      ImportField(
        'name',
        'Checklist name',
        required: true,
        min: 2,
        aliases: ['checklist', 'template'],
      ),
      ImportField(
        'item_label',
        'Checklist item',
        required: true,
        aliases: ['item', 'task'],
      ),
    ],
    ['name', 'item_label'],
  ),
  ImportSchema(
    'documents',
    'Documents & procedures',
    Permission.documentManage,
    [
      _requiredId,
      ImportField('title', 'Title', required: true, min: 2, aliases: ['name']),
      ImportField(
        'body',
        'Content',
        required: true,
        aliases: ['text', 'content', 'procedure'],
      ),
    ],
    ['external_id'],
  ),
  ImportSchema(
    'wine_lists',
    'Wine lists & menus',
    Permission.wineListPublish,
    [
      _name,
      ImportField(
        'kind',
        'List type',
        required: true,
        choices: ['glass', 'bottle', 'reserve', 'member', 'event'],
        aliases: ['type'],
      ),
      ImportField(
        'threshold',
        'Low stock threshold',
        type: ImportValueType.integer,
        min: 0,
        defaultValue: '2',
      ),
    ],
    ['name', 'kind'],
  ),
  ImportSchema(
    'list_items',
    'Wine list items',
    Permission.wineListPublish,
    [
      ImportField(
        'list_name',
        'List name',
        required: true,
        aliases: ['list', 'menu'],
      ),
      ImportField(
        'list_kind',
        'List type',
        required: true,
        choices: ['glass', 'bottle', 'reserve', 'member', 'event'],
      ),
      _sku,
      ImportField(
        'pour_ml',
        'Pour size (ml)',
        type: ImportValueType.integer,
        min: 1,
      ),
    ],
    ['list_name', 'list_kind', 'sku'],
  ),
];

String normalizeImportHeader(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

Map<String, int> suggestImportMapping(
  ImportSchema schema,
  List<String> headers,
) {
  final normalized = headers.map(normalizeImportHeader).toList();
  return {
    for (final field in schema.fields)
      if (normalized.any(
        (header) => [
          field.key,
          normalizeImportHeader(field.label),
          ...field.aliases,
        ].contains(header),
      ))
        field.key: normalized.indexWhere(
          (header) => [
            field.key,
            normalizeImportHeader(field.label),
            ...field.aliases,
          ].contains(header),
        ),
  };
}
