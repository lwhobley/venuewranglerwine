// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tenant_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Organization _$OrganizationFromJson(Map<String, dynamic> json) =>
    _Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      legalName: json['legal_name'] as String?,
    );

Map<String, dynamic> _$OrganizationToJson(_Organization instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'legal_name': instance.legalName,
    };

_Venue _$VenueFromJson(Map<String, dynamic> json) => _Venue(
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  name: json['name'] as String,
  slug: json['slug'] as String,
  timezone: json['timezone'] as String,
  currencyCode: json['currency_code'] as String,
  serviceStyle: json['service_style'] as String,
  status: json['status'] as String,
  city: json['city'] as String?,
);

Map<String, dynamic> _$VenueToJson(_Venue instance) => <String, dynamic>{
  'id': instance.id,
  'organization_id': instance.organizationId,
  'name': instance.name,
  'slug': instance.slug,
  'timezone': instance.timezone,
  'currency_code': instance.currencyCode,
  'service_style': instance.serviceStyle,
  'status': instance.status,
  'city': instance.city,
};
