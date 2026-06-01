use aztec::{
    context::PrivateContext,
    note::{
        ConfirmedNote,
        note_getter::get_notes,
        note_getter_options::NoteGetterOptions,
        note_interface::{NoteHash, NoteType},
    },
    protocol::{
        address::AztecAddress,
        constants::NOTE_HASH_TREE_HEIGHT,
        hash::{compute_siloed_note_hash, compute_unique_note_hash},
        merkle_tree::{MembershipWitness, root_from_sibling_path},
        traits::Packable,
    },
};

pub fn assert_note_inclusion<NOTE>(
    note: NOTE,
    owner: AztecAddress,
    randomness: Field,
    note_nonce: Field,
    membership_witness: MembershipWitness<NOTE_HASH_TREE_HEIGHT>,
    contract_address: AztecAddress,
    storage_slot: Field,
    note_hash_tree_root: Field,
)
where
    NOTE: NoteHash,
{
    // Compute the note hash using the NoteHash trait
    let note_hash = note.compute_note_hash(owner, storage_slot, randomness);

    // Silo the note hash with the contract address
    let siloed_note_hash = compute_siloed_note_hash(contract_address, note_hash);

    // Compute the unique note hash (this is what's stored in the tree)
    let unique_note_hash = compute_unique_note_hash(note_nonce, siloed_note_hash);

    // Verify membership in the note hash tree
    let computed_root = root_from_sibling_path(
        unique_note_hash,
        membership_witness.leaf_index,
        membership_witness.sibling_path,
    );
    assert(
        computed_root == note_hash_tree_root,
        f"root mismatch: {computed_root} != {note_hash_tree_root}",
    );
}

pub fn get_note_inclusion_data<NOTE, let M: u32, PREPROCESSOR_ARGS, FILTER_ARGS>(
    context: &mut PrivateContext,
    storage_slot: Field,
    options: NoteGetterOptions<NOTE, M, PREPROCESSOR_ARGS, FILTER_ARGS>,
) -> NoteInclusionData<NOTE>
where
    NOTE: NoteType + NoteHash + Packable + Eq,
{
    let confirmed_notes = get_notes(context, storage_slot, options);
    let confirmed_note = confirmed_notes.get(0);

    // The proven_note_hash is the note hash used to prove existence
    let note_hash = confirmed_note.proven_note_hash;

    NoteInclusionData { note: confirmed_note, note_hash }
}

pub struct NoteInclusionData<Note> {
    pub note: ConfirmedNote<Note>,
    pub note_hash: Field,
}
