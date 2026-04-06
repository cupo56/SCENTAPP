-- Fix: Spalte is_empty in user_perfumes umbenennen zu is_want_to_try
-- is_empty war semantisch falsch: der Swift-Code nutzt die Spalte als "möchte ich ausprobieren",
-- nicht als "kein Status gesetzt". Die Umbenennung macht DB und Code konsistent.

ALTER TABLE public.user_perfumes
  RENAME COLUMN is_empty TO is_want_to_try;
