import { squareSales, squareSearchBody } from './square.ts';

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

Deno.test('Square pulls completed orders from only the mapped location', () => {
  assertEquals(squareSearchBody('square-a').location_ids, ['square-a']);
  assertEquals(squareSearchBody('square-a').query.filter.state_filter.states, ['COMPLETED']);
  const sales = squareSales({ orders: [
    { id: 'paid-a', state: 'COMPLETED', location_id: 'square-a',
      line_items: [{ catalog_object_id: 'variation-1', quantity: '2' }] },
    { id: 'open-a', state: 'OPEN', location_id: 'square-a' },
    { id: 'canceled-a', state: 'CANCELED', location_id: 'square-a' },
    { id: 'paid-b', state: 'COMPLETED', location_id: 'square-b' },
  ] }, 'square-a');
  assertEquals(sales.map((sale) => sale.externalId), ['paid-a']);
  assertEquals(sales[0].lines[0].sku, 'variation-1');
});
