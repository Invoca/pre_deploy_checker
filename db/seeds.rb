# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

ancestor_refs = AncestorRef.create(
  [
    { service_name: 'web',        ref: 'production' },
    { service_name: 'rs_west',    ref: '2b7a8338fde0a998d8aa6b540f1aa4dcb3f9018f' },
    { service_name: 'rs_east',    ref: '2b7a8338fde0a998d8aa6b540f1aa4dcb3f9018f' },
    { service_name: 'rs_central', ref: '2b7a8338fde0a998d8aa6b540f1aa4dcb3f9018f' }
  ]
)
