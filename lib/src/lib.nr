use aztec::{
    note::note_interface::NoteHash,
    protocol::{
        address::AztecAddress,
        constants::NOTE_HASH_TREE_HEIGHT,
        merkle_tree::{membership::MembershipWitness, root::root_from_sibling_path},
    },
};

/// Asserts that a note is included in the note hash tree at the given root.
///
/// This function verifies a merkle inclusion proof for a note.
///
/// # Arguments
/// * `note` - The note to verify inclusion for
/// * `owner` - The owner of the note
/// * `storage_slot` - The storage slot where the note is stored
/// * `randomness` - The randomness used in the note hash computation
/// * `membership_witness` - The merkle membership witness containing the sibling path
/// * `note_hash_tree_root` - The expected root of the note hash tree
pub fn assert_note_inclusion<NOTE>(
    note: NOTE,
    owner: AztecAddress,
    storage_slot: Field,
    randomness: Field,
    membership_witness: MembershipWitness<NOTE_HASH_TREE_HEIGHT>,
    note_hash_tree_root: Field,
)
where
    NOTE: NoteHash,
{
    // Compute the note hash using the NoteHash trait
    let note_hash = note.compute_note_hash(owner, storage_slot, randomness);
    let computed_root = root_from_sibling_path(
        note_hash,
        membership_witness.leaf_index,
        membership_witness.sibling_path,
    );
    assert(
        computed_root == note_hash_tree_root,
        f"root mismatch: {computed_root} != {note_hash_tree_root}",
    );
}

/// Computes the note hash for a given note.
///
/// # Arguments
/// * `note` - The note to compute the hash for
/// * `owner` - The owner of the note
/// * `storage_slot` - The storage slot where the note is stored
/// * `randomness` - The randomness used in the note hash computation
///
/// # Returns
/// The computed note hash
pub fn compute_note_hash<NOTE>(
    note: NOTE,
    owner: AztecAddress,
    storage_slot: Field,
    randomness: Field,
) -> Field
where
    NOTE: NoteHash,
{
    note.compute_note_hash(owner, storage_slot, randomness)
}

/// Data structure containing note information for inclusion proofs.
pub struct NoteInclusionData<Note> {
    pub note: Note,
    pub owner: AztecAddress,
    pub storage_slot: Field,
    pub randomness: Field,
    pub note_hash: Field,
}

impl<Note> NoteInclusionData<Note>
where
    Note: NoteHash,
{
    pub fn new(note: Note, owner: AztecAddress, storage_slot: Field, randomness: Field) -> Self {
        let note_hash = note.compute_note_hash(owner, storage_slot, randomness);
        Self { note, owner, storage_slot, randomness, note_hash }
    }
}
