package de.eachandevery.cuelens.infofeed

data class InfoMessage(
    val id: Long,
    val createdAtUtc: String,
    val textDe: String,
    val textEn: String
)
