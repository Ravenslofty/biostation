void* memcpy(void* dest, const void* src, unsigned int count)
{
    char* dest_ = (char*)dest;
    char* src_ = (char*)src;

    for (; count; count--) {
        *dest_ = *src_;
        dest_++;
        src_++;
    }
    return dest;
}
