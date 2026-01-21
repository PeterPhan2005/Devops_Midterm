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
    
    @Autowired
    private FileStorageService fileStorageService;
    
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
            String storedFileName = fileStorageService.storeFile(file);
            note.setFileName(file.getOriginalFilename());
            note.setFileType(file.getContentType());
            note.setAttachmentUrl("/uploads/" + storedFileName);
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
            
            // Delete old file if exists
            if (note.getAttachmentUrl() != null) {
                String oldFileName = note.getAttachmentUrl().replace("/uploads/", "");
                fileStorageService.deleteFile(oldFileName);
            }
            
            // Store new file
            String storedFileName = fileStorageService.storeFile(file);
            note.setFileName(file.getOriginalFilename());
            note.setFileType(file.getContentType());
            note.setAttachmentUrl("/uploads/" + storedFileName);
        }
        
        Note updatedNote = noteRepository.save(note);
        return convertToDTO(updatedNote);
    }
    
    public void deleteNote(Long id) {
        Note note = noteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Note not found with id: " + id));
        
        // Delete file if exists
        if (note.getAttachmentUrl() != null) {
            String fileName = note.getAttachmentUrl().replace("/uploads/", "");
            fileStorageService.deleteFile(fileName);
        }
        
        noteRepository.deleteById(id);
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
        dto.setAttachmentUrl(note.getAttachmentUrl());
        dto.setHasFile(note.getAttachmentUrl() != null && !note.getAttachmentUrl().isEmpty());
        dto.setCreatedAt(note.getCreatedAt());
        dto.setUpdatedAt(note.getUpdatedAt());
        return dto;
    }
}
