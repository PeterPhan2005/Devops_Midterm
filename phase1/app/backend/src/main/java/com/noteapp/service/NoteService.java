package com.noteapp.service;

import com.noteapp.dto.NoteDTO;
import com.noteapp.entity.Note;
import com.noteapp.repository.NoteRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class NoteService {
    
    @Autowired
    private NoteRepository noteRepository;
    
    public List<NoteDTO> getAllNotes() {
        return noteRepository.findAllByOrderByUpdatedAtDesc()
                .stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }
    
    public NoteDTO getNoteById(Long id) {
        Note note = noteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Note not found with id: " + id));
        return convertToDTO(note);
    }
    
    public NoteDTO createNote(String title, String content, MultipartFile file) throws IOException {
        Note note = new Note();
        note.setTitle(title);
        note.setContent(content);
        
        if (file != null && !file.isEmpty()) {
            validateFileSize(file);
            note.setFileName(file.getOriginalFilename());
            note.setFileType(file.getContentType());
            note.setFileData(file.getBytes());
        }
        
        Note savedNote = noteRepository.save(note);
        return convertToDTO(savedNote);
    }
    
    public NoteDTO updateNote(Long id, String title, String content, MultipartFile file) throws IOException {
        Note note = noteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Note not found with id: " + id));
        
        note.setTitle(title);
        note.setContent(content);
        
        if (file != null && !file.isEmpty()) {
            validateFileSize(file);
            note.setFileName(file.getOriginalFilename());
            note.setFileType(file.getContentType());
            note.setFileData(file.getBytes());
        }
        
        Note updatedNote = noteRepository.save(note);
        return convertToDTO(updatedNote);
    }
    
    public void deleteNote(Long id) {
        if (!noteRepository.existsById(id)) {
            throw new RuntimeException("Note not found with id: " + id);
        }
        noteRepository.deleteById(id);
    }
    
    public byte[] getFileData(Long id) {
        Note note = noteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Note not found with id: " + id));
        
        if (note.getFileData() == null) {
            throw new RuntimeException("No file attached to this note");
        }
        
        return note.getFileData();
    }
    
    public String getFileName(Long id) {
        Note note = noteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Note not found with id: " + id));
        return note.getFileName();
    }
    
    public String getFileType(Long id) {
        Note note = noteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Note not found with id: " + id));
        return note.getFileType();
    }
    
    private void validateFileSize(MultipartFile file) {
        long maxSize = 5 * 1024 * 1024; // 5MB
        if (file.getSize() > maxSize) {
            throw new RuntimeException("File size exceeds maximum limit of 5MB");
        }
    }
    
    private NoteDTO convertToDTO(Note note) {
        NoteDTO dto = new NoteDTO();
        dto.setId(note.getId());
        dto.setTitle(note.getTitle());
        dto.setContent(note.getContent());
        dto.setFileName(note.getFileName());
        dto.setFileType(note.getFileType());
        dto.setHasFile(note.getFileData() != null && note.getFileData().length > 0);
        dto.setCreatedAt(note.getCreatedAt());
        dto.setUpdatedAt(note.getUpdatedAt());
        return dto;
    }
}
