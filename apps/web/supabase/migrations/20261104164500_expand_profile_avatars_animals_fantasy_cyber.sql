alter table public.profiles
  drop constraint profiles_avatar_key_check;

alter table public.profiles
  add constraint profiles_avatar_key_check check (
    avatar_key in (
      'forge', 'flame', 'mint', 'captain', 'rebel', 'ninja', 'royal', 'racer',
      'night', 'panda', 'fox', 'owl', 'shark', 'dragon', 'bunny', 'yeti',
      'orbit', 'comet', 'nova', 'alien', 'rover', 'lunar', 'solar', 'void',
      'pixel', 'arcade', 'cassette', 'glitch', 'neon', 'synth',
      'invader', 'ghost', 'knight', 'wizard', 'toad', 'heartbit', 'boombox', 'chip',
      'wolf', 'bear', 'penguin', 'frog', 'lion', 'bee',
      'elf', 'orc', 'fairy', 'golem', 'phoenix', 'mermaid',
      'cyborg', 'hacker', 'drone', 'matrix', 'laser', 'android'
    )
  );
