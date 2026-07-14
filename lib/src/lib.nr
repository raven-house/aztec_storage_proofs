use aztec::{
    context::PrivateContext,
    note::{
        ConfirmedNote,
        HintedNote,
        note_getter::get_notes,
        note_getter_options::NoteGetterOptions,
        note_interface::{NoteHash, NoteType},
    },
    protocol::{
        address::AztecAddress,
        constants::NOTE_HASH_TREE_HEIGHT,
        hash::{compute_siloed_note_hash, compute_unique_note_hash},
        merkle_tree::{membership::MembershipWitness, root::root_from_sibling_path},
        traits::{Deserialize, Packable, Serialize},
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
    // Recompute the unique note hash that is stored as a leaf in the note hash tree for a settled note. Since 4.3.0
    // notes no longer embed their owner/randomness, so these are passed alongside the note in order to compute the
    // inner (non-siloed) note hash.
    let inner_note_hash = note.compute_note_hash(owner, storage_slot, randomness);
    let siloed_note_hash = compute_siloed_note_hash(contract_address, inner_note_hash);
    let unique_note_hash = compute_unique_note_hash(note_nonce, siloed_note_hash);

    // storage proof
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

pub fn get_note_inclusion_data<NOTE, let M: u32, PreprocessorArgs, FilterArgs>(
    context: &mut PrivateContext,
    storage_slot: Field,
    options: NoteGetterOptions<NOTE, M, PreprocessorArgs, FilterArgs>,
) -> NoteInclusionData<NOTE>
where
    NOTE: NoteType + NoteHash + Eq + Packable<N = M>,
{
    let confirmed_notes: BoundedVec<ConfirmedNote<NOTE>, _> =
        get_notes(context, storage_slot, options);
    let confirmed_note = confirmed_notes.get(0);

    // Re-package the confirmed note as a `HintedNote`, which carries all the data required to later re-prove the
    // note's existence (and is `Serialize`able, unlike `ConfirmedNote`).
    let note = HintedNote {
        note: confirmed_note.note,
        contract_address: confirmed_note.contract_address,
        owner: confirmed_note.owner,
        randomness: confirmed_note.randomness,
        storage_slot: confirmed_note.storage_slot,
        metadata: confirmed_note.metadata,
    };
    // For a settled note the note hash used to prove existence is the unique note hash stored in the tree.
    let note_hash = confirmed_note.proven_note_hash;
    NoteInclusionData { note, note_hash }
}

#[derive(Serialize, Deserialize)]
pub struct NoteInclusionData<Note> {
    pub note: HintedNote<Note>,
    pub note_hash: Field,
}
