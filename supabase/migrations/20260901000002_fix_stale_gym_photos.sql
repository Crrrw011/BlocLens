-- Fix 12 stale place_ids that returned 404 and remove 2 gyms with no valid Place
update gyms set deleted_at = now(), updated_at = now() where id in ('9fd4cd76-2324-4ee7-8a75-fc3270a2d16c','cd1d94ab-c5db-4ebf-96c3-22df15d8c6c7') and deleted_at is null;

-- Refresh 12 expired place_ids (fresh searchText 2026-09-01)
update gyms set google_place_id = 'ChIJmb_cDV9_mmsR2NgMmgsAPPQ', updated_at = now() where id = '3b84500b-200a-4db0-9a05-ba138bb98dba';
update gyms set google_place_id = 'ChIJ9VSUxqfKcmsR1exYBPHa52E', updated_at = now() where id = 'dcb70a69-2d80-420b-a1f7-caea45673b0f';
update gyms set google_place_id = 'ChIJSWFFb0mrEmsRSUefvUMicu4', updated_at = now() where id = '0c183200-6e06-4c40-b300-3522d853f50c';
update gyms set google_place_id = 'ChIJL2_dH9-uEmsRnCQmsVFTPNk', updated_at = now() where id = '852710b3-2178-491e-9525-cc581f331405';
update gyms set google_place_id = 'ChIJfTMYy6pWkWsRkToOrvXe9SU', updated_at = now() where id = '4bd21655-66da-4070-9053-aab56fe66918';
update gyms set google_place_id = 'ChIJ2zd9TEWwEmsRkS54mOdlr0s', updated_at = now() where id = 'effc8960-05d1-43e4-8994-6de10e685668';
update gyms set google_place_id = 'ChIJqx1Cu9qlEmsRZzgKSyHNWfI', updated_at = now() where id = '624cf09a-b896-4226-b3d4-6268f3a0a24c';
update gyms set google_place_id = 'ChIJtQ_LiOuhEmsRPZK7VAFXL3o', updated_at = now() where id = 'ba11139c-f9d0-4f6a-9ce5-61057e7247d9';
update gyms set google_place_id = 'ChIJt_yoqKHHEmsRl7emUq8BJtg', updated_at = now() where id = 'e711ce39-1818-41fa-8acb-e6de3f823eb5';
update gyms set google_place_id = 'ChIJYzsm2CMa1moRHVXYC7PGoTg', updated_at = now() where id = '664fe0bb-c75c-4ea3-8fbf-55a000918814';
update gyms set google_place_id = 'ChIJMaK9Vz1b1moRgn-rKb_7BgQ', updated_at = now() where id = 'db02fe25-9060-4a7a-bf8f-c6bbc849ee24';
update gyms set google_place_id = 'ChIJAwMpjUlh1moRRPbYv11wtbU', updated_at = now() where id = '71446ff7-2245-44ea-9b58-460ccf8119f5';

-- Ensure 4 already-correct gyms are refreshed (prevent future expiry)
update gyms set google_place_id = 'ChIJeQ504eMVc2sR4Qb7R_qN64w', updated_at = now() where id = 'd7bcb82f-bc37-4d9f-9535-9c90916072de';
update gyms set google_place_id = 'ChIJtf48m1G9EmsR0nBG62sWMn4', updated_at = now() where id = '276d2fcd-78b3-43ed-8faa-4f3abb186ce1';
update gyms set google_place_id = 'ChIJL696RDbhI2sRuEylf2V4WMY', updated_at = now() where id = '9b19d98a-2e31-4d30-a6f3-900ad256f105';
update gyms set google_place_id = 'ChIJF2a-eIkT1GoRTlhC7T3hDpM', updated_at = now() where id = '562f1d25-268b-47f9-8f10-4a05d1e13f62';
