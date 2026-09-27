abstract final class Permission {
  static const orgRead = 'org.read';
  static const orgUpdate = 'org.update';
  static const venueCreate = 'venue.create';
  static const venueRead = 'venue.read';
  static const venueUpdate = 'venue.update';
  static const membershipRead = 'membership.read';
  static const membershipInvite = 'membership.invite';
  static const membershipApprove = 'membership.approve';
  static const membershipAssignRole = 'membership.assign_role';
  static const auditRead = 'audit.read';
  static const wineCatalogRead = 'wine.catalog.read';
  static const wineCatalogWrite = 'wine.catalog.write';
  static const wineCountExecute = 'wine.count.execute';
  static const wineCountReview = 'wine.count.review';
  static const wineCountApprove = 'wine.count.approve';
  static const wineMovementWrite = 'wine.movement.write';
  static const wineReceive = 'wine.receive';
  static const winePurchase = 'wine.purchase';
  static const wineCostRead = 'wine.cost.read';
  static const wineAllocationManage = 'wine.allocation.manage';
  static const wineListPublish = 'wine.list.publish';
  static const reservationRead = 'reservation.read';
  static const reservationWrite = 'reservation.write';
  static const reservationSeat = 'reservation.seat';
  static const floorRead = 'floor.read';
  static const floorDesign = 'floor.design';
  static const guestRead = 'guest.read';
  static const guestWrite = 'guest.write';
  static const scheduleRead = 'schedule.read';
  static const schedulePublish = 'schedule.publish';
  static const timeclockSelf = 'timeclock.self';
  static const timeclockManage = 'timeclock.manage';
  static const checklistExecute = 'checklist.execute';
  static const checklistManage = 'checklist.manage';
  static const logbookWrite = 'logbook.write';
  static const documentRead = 'document.read';
  static const documentManage = 'document.manage';
  static const chatWrite = 'chat.write';
  static const eventRead = 'event.read';
  static const eventManage = 'event.manage';
  static const salesRead = 'sales.read';
  static const reportOperational = 'report.operational';
  static const reportFinancial = 'report.financial';
  static const integrationManage = 'integration.manage';
  static const billingManage = 'billing.manage';
  static const settingsManage = 'settings.manage';

  static const all = <String>[
    orgRead,
    orgUpdate,
    venueCreate,
    venueRead,
    venueUpdate,
    membershipRead,
    membershipInvite,
    membershipApprove,
    membershipAssignRole,
    auditRead,
    wineCatalogRead,
    wineCatalogWrite,
    wineCountExecute,
    wineCountReview,
    wineCountApprove,
    wineMovementWrite,
    wineReceive,
    winePurchase,
    wineCostRead,
    wineAllocationManage,
    wineListPublish,
    reservationRead,
    reservationWrite,
    reservationSeat,
    floorRead,
    floorDesign,
    guestRead,
    guestWrite,
    scheduleRead,
    schedulePublish,
    timeclockSelf,
    timeclockManage,
    checklistExecute,
    checklistManage,
    logbookWrite,
    documentRead,
    documentManage,
    chatWrite,
    eventRead,
    eventManage,
    salesRead,
    reportOperational,
    reportFinancial,
    integrationManage,
    billingManage,
    settingsManage,
  ];

  static const descriptions = <String, String>{
    orgRead: 'View the organization profile',
    orgUpdate: 'Update organization identity',
    venueCreate: 'Create a venue',
    venueRead: 'View venue profile and hours',
    venueUpdate: 'Update venue settings',
    membershipRead: 'View team memberships',
    membershipInvite: 'Invite a person to the organization',
    membershipApprove: 'Approve or decline a join request',
    membershipAssignRole: 'Change an existing membership role',
    auditRead: 'Read the audit log',
    wineCatalogRead: 'View the wine catalog',
    wineCatalogWrite: 'Edit wine master data',
    wineCountExecute: 'Enter inventory counts',
    wineCountReview: 'Review count variances',
    wineCountApprove: 'Approve count adjustments',
    wineMovementWrite: 'Move or transfer inventory',
    wineReceive: 'Receive purchase orders',
    winePurchase: 'Create purchase orders and manage vendors',
    wineCostRead: 'View unit cost and valuation',
    wineAllocationManage: 'Manage club allocations and member holdings',
    wineListPublish: 'Publish wine list availability',
    reservationRead: 'View reservations',
    reservationWrite: 'Create and edit reservations',
    reservationSeat: 'Seat, waitlist, and complete covers',
    floorRead: 'View the live floor',
    floorDesign: 'Edit floor layouts',
    guestRead: 'View guest profiles',
    guestWrite: 'Edit guest profiles and notes',
    scheduleRead: 'View the published schedule',
    schedulePublish: 'Publish schedules',
    timeclockSelf: 'Clock in and out for yourself',
    timeclockManage: 'Review and correct time entries',
    checklistExecute: 'Complete assigned checklist items',
    checklistManage: 'Manage checklist templates and signoff',
    logbookWrite: 'Write manager logbook notes',
    documentRead: 'Read authorized documents',
    documentManage: 'Manage documents and acknowledgments',
    chatWrite: 'Send team messages',
    eventRead: 'View events and BEOs',
    eventManage: 'Manage events and BEOs',
    salesRead: 'View sales snapshots',
    reportOperational: 'View operational reports',
    reportFinancial: 'View cost, margin, and financial reports',
    integrationManage: 'Connect external systems',
    billingManage: 'Manage subscription and billing',
    settingsManage: 'Manage venue settings',
  };
}
