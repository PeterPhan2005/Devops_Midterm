package com.noteapp.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class NoteDTO {
    private Long id;
    private String title;
    private String content;
    private String fileName;
    private String fileType;
    private String attachmentUrl;
    private boolean hasFile;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
