# `DumbDBM_File` --- Portable DBM implementation

With `dumbdbm` / `dbm.dumb` the Python programming language provides a very simple DBM style database (i.e. a key-value database) written entirely in Python, requiring no external library. Being slow and some kind of *dumb*, it is intended as a last resort fallback if no other (more robust) database modules like GDBM, NDBM or Berkeley DB are available.

In 2011, when I felt boring, I translated the Python module to the Perl programming language. The result was a module named `DumbDBM_File` providing a `tie()` compatible interface for DumbDBM files. This Perl implementation is fully compatible to the original Python one (and contains the same problems, see *Bugs and problems*).

Beware that this is actually a fun project. I programmed this because I wanted to see if I can do it. And I published it in 2019 to GitHub, because I thought it could be interesting for learning purposes. If possible, please consider using a proper database system.

## Synopsis of `DumbDBM_File`

```
use DumbDBM_File;

# Opening a database file called "homer.db"
# Creating it if necessary

my %db;
tie(%db,'DumbDBM_File','homer.db');

# Assigning some values

$db{'name'} = 'Homer';
$db{'wife'} = 'Marge';
$db{'child'} = 'Bart';
$db{'neighbor'} = 'Flanders';

# Print value of "name": Homer

print $db{'name'};

# Overwriting a value

$db{'child'} = 'Lisa';

# Remove a value
# The value remains in the database file, just the index entry gets removed,
# meaning you can't retrieve the value from the database file any more

delete($db{'neighbor'});

# Close the database file

untie %db;
```

## Bugs and problems

This module is a direct port of the Python module containing the same bugs and problems:

* Seems to contain a bug when updating (I don't know what the bug actually is, I took this information directly from a comment in `dumbdbm`'s source code)
* Free space is not reclaimed
* No concurrent access is supported (if two processes access the database, they may mess up the index)
* This module always reads the whole index file and some updates rewrite the whole index
* No read-only mode

## Format description

### Files

Consider having a database called `example`, you have up to three files:

#### `example.dir`

This is an index file containing information for retrieving the values out of the database. It is a text file containing the key, the file offset and the size of each value.

#### `example.dir.bak`

This file **may** containg a backup of the index file.

#### `example.dat`

This is the database file containing the values separated by zero-bytes (meaning `\0`).

### Index file

The index file is a text file. It just contains the keys, not the values.

Each line describes a key and where to find its value in the database file:

`'key', (pos, siz)`

* `key`: Key of the data tuple
* `pos`: Byte offset in the database file where the value is located
* `siz`: Size of the value

When searching for a value in the database, only the the index file is considered. If a key does not exist in the index file, the corresponding value cannot be retrieved from the database file anymore.

### Database file

The database file is a binary file consisting of blocks with a size of 512 bytes by default. It just contains the values, not the keys.

The value is inserted into a block. If the value is too big, more than one block is used. This means, a value of 511 bytes uses one block and a value of 512 uses one block. But a value of 513 bytes uses two blocks. If the last block of a value is not completeley used, it gets filled with zero-bytes.

When a value is modified and the new value fits in the old set of blocks, the old ones are used. Otherwise, a new set of blocks is placed at the end of the file.

Currently, when a value is removed from the database, only it's entry in the index file is removed, meaning that it is still in the database. This also means, that it will become unaccessible and rendering the corresponding blocks lost. A similar thing happens when a value is moved to different blocks: The index file points to the value in the new blocks, but the old blocks remain unaccessible in the database file.

## License

The original Python module is licensed under the terms of the Python Software License: https://www.python.org/psf/license/

The Perl implementation `DumbDBM_File` is licensed under the terms of the 2-Clause BSD License (see file *LICENSE*).

## Credits

* `DumbDBM_File`: Patrick Canterino, https://www.patrick-canterino.de/
* `dumbdbm` / `dbm.dumb` (original Python implementation:) Python Software Foundation