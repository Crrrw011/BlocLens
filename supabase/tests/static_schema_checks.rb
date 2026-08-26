#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
MIGRATIONS = ROOT.join("supabase/migrations")
SEED = ROOT.join("supabase/seed.sql")

EXPECTED_TABLES = %w[
  profiles app_user_roles gyms gym_facilities gym_memberships wall_zones routes
  gym_reset_patterns reset_events reset_confirmations route_photos
  route_photo_helpful_votes beta_links beta_helpful_votes beta_comments
  logbook_entries route_grade_votes route_corrections route_removal_reports
  route_merge_suggestions content_reports moderation_actions favourite_gyms
  user_follows user_blocks notification_preferences notification_outbox
  gym_claims app_feedback
].freeze
EXPECTED_VIEWS = %w[
  public_profiles gym_summaries wall_zone_summaries route_summaries
  beta_ranking_inputs reset_summaries moderation_queue gym_official_scope
].freeze

errors = []
files = MIGRATIONS.glob("*.sql").sort
expected_names = (1..12).map { |number| format("%04d", number) }
actual_names = files.map { |file| file.basename.to_s.split("_").first }
errors << "Migration numbering is incomplete or out of order." unless actual_names == expected_names

combined = files.map do |file|
  sql = file.read
  errors << "#{file.basename} is empty." if sql.strip.empty?
  errors << "#{file.basename} does not end with a semicolon." unless sql.rstrip.end_with?(";")
  errors << "#{file.basename} has unbalanced dollar quotes." unless sql.scan("$$").length.even?
  sql
end.join("\n")
executable_sql = combined.gsub(/--.*$/, "")

EXPECTED_TABLES.each do |table|
  escaped = Regexp.escape(table)
  errors << "Missing table: #{table}." unless combined.match?(/create table public\.#{escaped}\b/i)
  errors << "RLS is not enabled for #{table}." unless combined.match?(
    /alter table public\.#{escaped} enable row level security;/i
  )
  errors << "No RLS policy exists for #{table}." unless combined.match?(
    /create policy\s+\w+\s+on public\.#{escaped}\b/i
  )
end

EXPECTED_VIEWS.each do |view|
  errors << "View #{view} is missing or is not security-invoker." unless combined.match?(
    /create view public\.#{Regexp.escape(view)}\s+with\s*\(security_invoker\s*=\s*true\)/im
  )
end

combined.scan(/create(?: or replace)? function.*?(?=create(?: or replace)? function|\z)/im).each do |function_sql|
  next unless function_sql.match?(/security definer/i)

  function_name = function_sql[/function\s+public\.(\w+)/i, 1] || "unknown"
  errors << "SECURITY DEFINER function #{function_name} has no empty search_path." unless function_sql.match?(
    /set search_path = ''/i
  )
end

errors << "A video table is present." if executable_sql.match?(/create table\s+(?:public\.)?\w*video\w*/i)
errors << "A video Storage bucket is present." if executable_sql.match?(/storage[^\n]*(?:video|videos)/i)
wall_zone_definition = executable_sql[
  /create table public\.wall_zones\s*\(.*?\n\);/im
] || ""
errors << "Wall-zone geometry is present." if wall_zone_definition.match?(
  /\b(?:geometry|polygon|hotspot|floor_plan|coordinate_[xy])\b/i
)
errors << "A credential-like value is present." if combined.match?(
  /(?:service_role|anon_key|supabase_url)\s*[=:]\s*['\"][^'\"]+/i
)

# Stage 6D-2A beta access hardening
errors << "Anonymous beta_links SELECT revoke is missing." unless combined.match?(/revoke select on public\.beta_links from anon;/i)
errors << "Anonymous beta_ranking_inputs SELECT revoke is missing." unless combined.match?(/revoke select on public\.beta_ranking_inputs from anon;/i)
errors << "Beta count helper is missing." unless combined.match?(/visible_beta_count_for_route/i)
errors << "Client function privileges are not reset." unless combined.match?(
  /revoke execute on all functions in schema public from PUBLIC, anon, authenticated;/i
)
errors << "Client view privileges are not reset." unless combined.match?(
  /revoke all privileges on table.*?from PUBLIC, anon, authenticated;/im
)
errors << "citext is not moved out of public." unless combined.match?(
  /alter extension citext set schema extensions;/i
)
errors << "Beta normalisation does not use a fixed search_path." unless combined.match?(
  /function public\.normalise_beta_link\(\).*?set search_path = ''/im
)
errors << "pg_trgm extension is missing." unless combined.match?(/create extension if not exists pg_trgm/i)
%w[gyms_name_trgm_idx gyms_suburb_trgm_idx wall_zones_name_trgm_idx routes_colour_trgm_idx routes_label_trgm_idx].each do |index_name|
  errors << "Trigram index #{index_name} is missing." unless combined.match?(/#{Regexp.escape(index_name)}/i)
end

swift_sources = ROOT.glob("BlocLens/**/*.swift").map(&:read).join("\n")
errors << "A Video DTO or Storage model is present in Swift." if swift_sources.match?(
  /\b(?:struct|class|enum)\s+(?:Video|VideoRecord|VideoStorage|VideoUpload)\b/
)

seed = SEED.read
{
  "Gym" => ["10000000-0000-4000-8000-", 3],
  "Wall Zone" => ["20000000-0000-4000-8000-", 9],
  "Route" => ["30000000-0000-4000-8000-", 27],
  "Beta Link" => ["40000000-0000-4000-8000-", 6]
}.each do |label, (prefix, expected)|
  count = seed.scan(/#{Regexp.escape(prefix)}\d{12}/).uniq.length
  errors << "#{label} seed count is #{count}; expected #{expected}." unless count == expected
end

external_hosts = seed.scan(%r{https?://([^/'"\s]+)}i).flatten.uniq
errors << "Seed contains a non-example external host: #{external_hosts.join(', ')}." unless external_hosts.all? {
  |host| host == "example.com"
}
errors << "Seed includes a non-development email." if seed.scan(/[\w.+-]+@[\w.-]+/).any? {
  |email| !email.end_with?(".invalid")
}

if errors.empty?
  puts "Static schema checks passed for #{files.count} migrations and the development seed."
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }.join("\n")
exit 1
