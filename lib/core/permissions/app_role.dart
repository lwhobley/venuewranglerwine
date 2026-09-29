enum AppRole {
  organizationOwner('organization_owner', 'Organization owner', 10),
  venueAdministrator('venue_administrator', 'Venue administrator', 20),
  generalManager('general_manager', 'General manager', 30),
  beverageDirector('beverage_director', 'Beverage director', 40),
  eventManager('event_manager', 'Event manager', 40),
  floorManager('floor_manager', 'Floor manager', 50),
  scheduler('scheduler', 'Scheduler', 50),
  departmentManager('department_manager', 'Department manager', 45),
  shiftLead('shift_lead', 'Shift lead', 55),
  employee('employee', 'Employee', 70),
  host('host', 'Host', 60),
  bartender('bartender', 'Bartender', 60),
  server('server', 'Server', 70),
  inventoryCounter('inventory_counter', 'Inventory counter', 70),
  auditor('auditor', 'Read-only auditor', 120);

  const AppRole(this.key, this.label, this.rank);

  final String key;
  final String label;
  final int rank;

  static AppRole? byKey(String key) {
    for (final role in AppRole.values) {
      if (role.key == key) return role;
    }
    return null;
  }

  static List<AppRole> assignableBy(AppRole actor) {
    return AppRole.values.where((role) => role.rank >= actor.rank).toList();
  }
}
