"""File hashing utilities for change detection."""

import hashlib
from pathlib import Path
from typing import Optional
import logging

from config import Config

logger = logging.getLogger(__name__)


def compute_file_hash(file_path: Path, algorithm: str = 'sha256') -> str:
    """
    Compute hash of a file.
    
    Args:
        file_path: Path to file
        algorithm: Hash algorithm (sha256, sha1, md5)
    
    Returns:
        Hex digest of file hash
    """
    hash_func = getattr(hashlib, algorithm)()
    
    with open(file_path, 'rb') as f:
        # Read in chunks for large files
        for chunk in iter(lambda: f.read(8192), b''):
            hash_func.update(chunk)
    
    return hash_func.hexdigest()


def file_changed(file_path: Path, db, recorded_hash: Optional[str] = None) -> bool:
    """
    Check if file has changed since last processing.
    
    Args:
        file_path: Path to file
        db: Database instance
        recorded_hash: Previously recorded hash (if known)
    
    Returns:
        True if file has changed or is new, False otherwise
    """
    if not Config.SKIP_UNCHANGED_FILES:
        return True  # Always process if skipping is disabled
    
    current_hash = compute_file_hash(file_path, Config.HASH_ALGORITHM)
    
    # If hash provided, compare directly
    if recorded_hash:
        return current_hash != recorded_hash
    
    # Otherwise, check database
    result = db.fetchone(
        "SELECT sha256_hash FROM file_hashes WHERE file_path = ?",
        (str(file_path),)
    )
    
    if not result:
        return True  # New file
    
    return current_hash != result[0]


def record_file_hash(file_path: Path, db, processing_status: str = 'completed'):
    """
    Record or update file hash in database.
    
    Args:
        file_path: Path to file
        db: Database instance
        processing_status: Status to record
    """
    file_hash = compute_file_hash(file_path, Config.HASH_ALGORITHM)
    file_stats = file_path.stat()
    
    # Check if record exists
    existing = db.fetchone(
        "SELECT id FROM file_hashes WHERE file_path = ?",
        (str(file_path),)
    )
    
    if existing:
        db.update(
            'file_hashes',
            {
                'sha256_hash': file_hash,
                'file_size_bytes': file_stats.st_size,
                'last_modified': file_stats.st_mtime,
                'last_processed': 'CURRENT_TIMESTAMP',
                'processing_status': processing_status
            },
            'file_path = ?',
            (str(file_path),)
        )
    else:
        db.insert('file_hashes', {
            'file_path': str(file_path),
            'sha256_hash': file_hash,
            'file_size_bytes': file_stats.st_size,
            'last_modified': file_stats.st_mtime,
            'last_processed': 'CURRENT_TIMESTAMP',
            'processing_status': processing_status
        })
    
    logger.debug(f"Recorded hash for {file_path.name}: {file_hash[:16]}...")