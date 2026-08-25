/// Every disguise name listed on the wiki's Disguises page
/// (wiki.toplinestudios.gg/wiki/Disguises), across every rarity and category
/// — including Admin and Staff skins, since those are also names a claim
/// could plausibly reference. Used only as autocomplete suggestions for the
/// claimant-name field: the field itself accepts free text, since new
/// disguises ship every couple of weeks and this list is a snapshot.
const List<String> kMafiaDisguiseNames = [
  // Default
  'Athena', 'Ella', 'Emma', 'Ethan', 'Grace', 'Jack', 'Laurel', 'Leo', 'Lila',
  'Lily', 'Lucas', 'Mia', 'Nick', 'Noah', 'Nora', 'Owen', 'Ryan', 'Sam',
  'Steven', 'Zoe',
  // Common
  'Alex', 'Anne', 'Bertram', 'Callum', 'Corey', 'Diego', 'Eva', 'Fallon',
  'Finlay', 'Hudson', 'Iris', 'Jose', 'Kirby', 'Melissa', 'Sadie', 'Shawn',
  'Sylvie', 'Tina', 'Toby', 'Tyler', 'Tyson', 'Wayne',
  // Uncommon
  'Aaliyah', 'Aaron', 'Amala', 'Andre', 'Belinda', 'Cameron', 'Chanel',
  'Cleo', 'Elisabeth', 'Harper', 'Isagani', 'Isaiah', 'Ivan', 'Joanna',
  'Kimberly', 'Liam', 'Luke', 'Martha', 'Mikayla', 'Rio', 'Sid', 'Sophie',
  'Zachary',
  // Rare
  'Amy', 'Billie', 'Cordelia', 'Cristal', 'Daphne', 'Fidel', 'Fiona',
  'Giselle', 'Hiraya', 'Jay', 'Jonas', 'Louis', 'Madison', 'Marco', 'Martin',
  'Mateo', 'Melania', 'Oliver', 'Paisley', 'Phoebe', 'Rome', 'Sean', 'Sue',
  'Tikay', 'Victoria',
  // Epic
  'Ariana', 'Candice', 'Carola', 'Cassandra', 'Celine', 'Clara', 'Dana',
  'Elena', 'Georgia', 'Maya', 'Monique', 'Paloma', 'Tanya', 'Theo',
  // Legendary
  'Beatrice', 'Bella', 'Gabe', 'Hugo', 'Lucia', 'Megan', 'Ruby', 'Seraphina',
  // Inner Circle
  'Adriana', 'Alessandra', 'Anok', 'Artemas', 'Avery', 'Azaria', 'Casper',
  'Celeste', 'Charlotte', 'Ciara', 'Cosmo', 'Cressida', 'Imani', 'Jada',
  'Kalisha', 'Kendrick', 'Lazula', 'Lola', 'Magdalena', 'Marcus', 'Max',
  'Nala', 'Natalia', 'Nicole', 'Ozias', 'Raquel', 'Seb', 'Solara', 'Thomas',
  'Tiamat', 'Virella', 'Vivienne',
  // Limited
  'Irene', 'Lestrade', 'Mary', 'Milverton', 'Moran', 'Moriarty', 'Mycroft',
  'Sherlock', 'Watson', 'Wiggins', 'Darcia', 'Dragan', 'Eclipse', 'Grozan',
  'Morte', 'Nyx', 'Raven', 'Schnabel',
  // Seasonal
  'Alucard', 'Carolyn', 'Emily', 'Fiend', 'Frankenstein', 'Hexa', 'Hollow',
  'Jackson', 'Sorceress', 'Aeloria', 'Cindy', 'Cinnamon', 'Elsa', 'Fairy',
  'Grinch', 'Hans', 'Mrs. Claus', 'Santa Claus', 'Amara', 'Amor', 'Valentin',
  'Valeria', 'Aoife', 'Cormac', 'Niamh', 'Seamus', 'Bobo/Bongo', 'Dylan',
  'Fluffy', 'Hazel', 'Hoppy', 'Jason', 'Kian', 'Matt', 'Molly', 'Olivia',
  'Poppy', 'Rosie', 'Trevor', 'Zuzanna', 'Benedict', 'Dakota', 'Dolly',
  'Hatter', 'Kayleigh', 'Liberty', 'Screech', 'Sierra',
  // Admin Characters
  'Argalia', 'Ado', 'Ascended Nick', 'Ayin', 'Benjamin', 'Cogbot', 'Dante',
  'David', 'Demian', 'Don Quixote', 'Duke', 'Gebura', 'Gojo', 'Haru Urara',
  'Kerberos', 'Lei Heng', 'Lucio', 'Matthias', 'Mafioso', 'Miku', 'Muhammad',
  'Ren', 'Rien', 'Ricardo', 'Rin', 'nil', 'Roland', 'Ryoshu', 'Sae',
  'Tamomo Cross', 'Teto', 'Toji', 'Tm Opera O', 'Valencina', 'Vergil',
  'Yoshihide', 'Yuji Itodori',
  // Staff
  'Ajax', 'Alune', 'Angel', 'Ashdyn', 'Aton-hotep', 'Ava', 'Catsuki',
  'Cairo', 'Ciel', 'Cinnamoroll', 'Cupid', "Elun'eo", 'Fernyra', 'Jasper',
  'Juno', 'Kasuma', 'Luna', 'Mei Mei', 'Miragé', 'Misa', 'Mrs Quinn',
  'Occisio', 'Ophelia', 'Persephone', 'Pythia', 'The Black Swordsman',
  'Uika', 'Vivi', 'Waddles', 'Yume Tuskino',
  // Removed
  'AJ', 'Alexis', 'Annalise', 'Blake', 'Bonnie', 'Camille', 'Ceara', 'Celia',
  'Chris', 'Cody', 'Connor', 'Elaine', 'Eloise', 'Gabriel', 'Graham',
  'Heather', 'Joseph', 'June', 'Justus', 'Kal', 'Kayla', 'Lindsay',
  'Lindsey', 'Lisa', 'Madelyn', 'Meadow', 'Michael', 'Ozzy', 'Priscilla',
  'Sandra', 'Tegan', 'Xavier',
];
