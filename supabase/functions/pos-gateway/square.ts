export function squareSearchBody(locationId: string, cursor?: string) {
  return {
    location_ids: [locationId],
    limit: 100,
    cursor,
    query: { filter: { state_filter: { states: ['COMPLETED'] } } },
  };
}

export function squareSales(payload: Record<string, unknown>, locationId: string) {
  return ((payload.orders ?? []) as Record<string, unknown>[])
    .filter((order) => order.state === 'COMPLETED' && order.location_id === locationId)
    .map((order) => ({
      externalId: String(order.id),
      occurredAt: String(order.closed_at ?? order.created_at),
      lines: ((order.line_items as Record<string, unknown>[]) ?? []).map((line) => ({
        sku: String(line.catalog_object_id ?? line.uid ?? ''),
        name: String(line.name ?? ''),
        quantity: String(line.quantity ?? '1'),
      })),
    }));
}
